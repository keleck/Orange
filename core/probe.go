package main

import (
	"bytes"
	"context"
	"errors"
	"io"
	"net"
	"github.com/metacubex/http"
	"time"

	"github.com/metacubex/mihomo/component/ca"
	"github.com/metacubex/mihomo/constant"
)

// 探测基础设施：所有请求都通过指定 proxy 拨号，因此拿到的是节点真实的
// 出口行为与出口 IP，而不是本机直连的结果。
const (
	probeConcurrency    = 8
	defaultProbeTimeout = 10 * time.Second
	probeErrorTimeout   = "timeout"
	probeErrorFailed    = "failed"

	probeScanChunk   = 32 * 1024
	probeScanOverlap = 256

	// Kept in step with browserUa in lib/common/constant.dart.
	browserUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)

var probeSlots = make(slots, probeConcurrency)

type probeDialer struct {
	proxy constant.Proxy
}

func probeMetadata(address string) (*constant.Metadata, error) {
	metadata := &constant.Metadata{
		NetWork: constant.TCP,
		Type:    constant.INNER,
		DNSMode: constant.DNSNormal,
		Process: constant.MihomoName,
	}
	if err := metadata.SetRemoteAddress(address); err != nil {
		return nil, err
	}
	return metadata, nil
}

func (d *probeDialer) dial(ctx context.Context, network, address string) (net.Conn, error) {
	metadata, err := probeMetadata(address)
	if err != nil {
		return nil, err
	}
	if d.proxy != nil {
		return d.proxy.DialContext(ctx, metadata)
	}
	var dialer net.Dialer
	return dialer.DialContext(ctx, network, address)
}

func probeErrorKind(err error) string {
	var netErr net.Error
	if errors.Is(err, context.DeadlineExceeded) || (errors.As(err, &netErr) && netErr.Timeout()) {
		return probeErrorTimeout
	}
	return probeErrorFailed
}

type probeRequest struct {
	method    string
	url       string
	proxyName string
	headers   map[string]string
	body      []byte
	timeout   time.Duration
	maxBody   int64

	// A followed redirect loses the Location that Netflix names its region in.
	noRedirect bool

	// until sees the latest chunk and probeScanOverlap bytes before it.
	until func(tail string) bool
}

type ProbeResult struct {
	StatusCode int
	Delay      int64
	Body       string
	Url        string
	Error      string
	Message    string

	header    http.Header
	lowerBody string
}

// runProbe returns nil when the request never got a slot before its deadline.
func runProbe(parent context.Context, req probeRequest) *ProbeResult {
	result := &ProbeResult{Url: req.url}
	fail := func(err error) *ProbeResult {
		result.Error = probeErrorKind(err)
		result.Message = err.Error()
		return result
	}

	dialer := &probeDialer{}
	if req.proxyName != "" {
		dialer.proxy = lookupProxy(req.proxyName)
		if dialer.proxy == nil {
			return fail(errors.New("proxy " + req.proxyName + " is not part of the applied config"))
		}
	}

	tlsConfig, err := ca.GetTLSConfig(ca.Option{})
	if err != nil {
		return fail(err)
	}

	timeout := req.timeout
	if timeout <= 0 {
		timeout = defaultProbeTimeout
	}
	if !probeSlots.acquireWithin(parent, timeout) {
		return nil
	}
	defer probeSlots.release()

	ctx, cancel := context.WithTimeout(parent, timeout)
	defer cancel()

	var body io.Reader
	if len(req.body) > 0 {
		body = bytes.NewReader(req.body)
	}
	method := req.method
	if method == "" {
		method = http.MethodGet
	}
	request, err := http.NewRequestWithContext(ctx, method, req.url, body)
	if err != nil {
		return fail(err)
	}
	for name, value := range req.headers {
		request.Header.Set(name, value)
	}
	transport := &http.Transport{
		DialContext:         dialer.dial,
		TLSClientConfig:     tlsConfig,
		TLSHandshakeTimeout: timeout,
		MaxIdleConns:        1,
		IdleConnTimeout:     timeout,
	}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport}
	if req.noRedirect {
		client.CheckRedirect = func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		}
	}

	start := time.Now()
	response, err := client.Do(request)
	if err != nil {
		return fail(err)
	}
	defer func() {
		_ = response.Body.Close()
	}()
	result.Delay = time.Since(start).Milliseconds()
	result.StatusCode = response.StatusCode
	result.header = response.Header
	result.Url = response.Request.URL.String()
	if req.maxBody > 0 {
		result.Body = readProbeBody(response.Body, req.maxBody, req.until)
	}
	return result
}

func readProbeBody(body io.Reader, maxBody int64, until func(string) bool) string {
	limited := io.LimitReader(body, maxBody)
	if until == nil {
		payload, _ := io.ReadAll(limited)
		return string(payload)
	}
	var buffer bytes.Buffer
	chunk := make([]byte, probeScanChunk)
	for {
		n, err := limited.Read(chunk)
		if n > 0 {
			start := buffer.Len() - probeScanOverlap
			if start < 0 {
				start = 0
			}
			buffer.Write(chunk[:n])
			if until(string(buffer.Bytes()[start:])) {
				break
			}
		}
		if err != nil {
			break
		}
	}
	return buffer.String()
}

func lookupProxy(name string) constant.Proxy {
	return proxiesWithProviders()[name]
}
