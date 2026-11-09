package main

import (
	"context"
	"net/netip"
	"strings"
	"sync"
	"time"

	"github.com/metacubex/http"
)

const (
	// Racing every source at once would take every probe slot.
	outboundIpConcurrency = 3
	outboundIpStagger     = 800 * time.Millisecond

	outboundIpMaxBody = 4096
)

type OutboundIpParams struct {
	ProxyName string   `json:"proxy-name"`
	Urls      []string `json:"urls"`
	Timeout   int64    `json:"timeout"`
}

type OutboundIpResult struct {
	Url   string `json:"url"`
	Body  string `json:"body"`
	Delay int64  `json:"delay"`
	Error string `json:"error,omitempty"`
}

// handleOutboundIp takes the first usable answer and cancels the losers so they
// stop occupying probe slots. Url is the source that was asked, not where it
// redirected, and Body is raw: Dart owns the sources and their parsers.
func handleOutboundIp(params *OutboundIpParams) *OutboundIpResult {
	if len(params.Urls) == 0 {
		return &OutboundIpResult{Error: probeErrorFailed}
	}

	timeout := timeoutFromMillis(params.Timeout, defaultProbeTimeout)
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	defer claimOutboundIp(cancel)()

	answers := make(chan *OutboundIpResult, len(params.Urls))
	next := 0
	inFlight := 0
	start := func() {
		if next >= len(params.Urls) || inFlight >= outboundIpConcurrency {
			return
		}
		url := params.Urls[next]
		next++
		inFlight++
		go func() {
			answers <- probeOutboundIpSource(ctx, url, params.ProxyName, timeout)
		}()
	}

	start()

	stagger := time.NewTicker(outboundIpStagger)
	defer stagger.Stop()
	for inFlight > 0 {
		select {
		case answer := <-answers:
			inFlight--
			if answer != nil {
				return answer
			}
			start()
		case <-stagger.C:
			start()
		case <-ctx.Done():
			return &OutboundIpResult{Error: probeErrorKind(ctx.Err())}
		}
	}
	return &OutboundIpResult{Error: probeErrorFailed}
}

var (
	outboundIpClaimsMu sync.Mutex
	outboundIpClaims   = map[*context.CancelFunc]struct{}{}
)

// Only one lookup needs to be live at a time: a newer one supersedes it.
func claimOutboundIp(cancel context.CancelFunc) func() {
	claim := &cancel
	outboundIpClaimsMu.Lock()
	for other := range outboundIpClaims {
		(*other)()
		delete(outboundIpClaims, other)
	}
	outboundIpClaims[claim] = struct{}{}
	outboundIpClaimsMu.Unlock()
	return func() {
		outboundIpClaimsMu.Lock()
		delete(outboundIpClaims, claim)
		outboundIpClaimsMu.Unlock()
	}
}

func probeOutboundIpSource(ctx context.Context, url string, proxyName string, timeout time.Duration) *OutboundIpResult {
	result := runProbe(ctx, probeRequest{
		method:    http.MethodGet,
		url:       url,
		proxyName: proxyName,
		headers:   map[string]string{"User-Agent": browserUserAgent},
		timeout:   timeout,
		maxBody:   outboundIpMaxBody,
	})
	if result == nil || result.Error != "" || result.StatusCode != http.StatusOK || !mentionsIp(result.Body) {
		return nil
	}
	return &OutboundIpResult{
		Url:   url,
		Body:  result.Body,
		Delay: result.Delay,
	}
}

// RFC 6598 space for carrier-grade NAT, which IsPrivate leaves out.
var sharedAddressSpace = netip.MustParsePrefix("100.64.0.0/10")

// A rate-limit or captcha page can still answer 200, and Dart cannot fall back
// once the race is decided, so a body without a public address must not win it.
func mentionsIp(body string) bool {
	tokens := strings.FieldsFunc(body, func(r rune) bool {
		return !(r == '.' || r == ':' || '0' <= r && r <= '9' || 'a' <= r && r <= 'z' || 'A' <= r && r <= 'Z')
	})
	for _, token := range tokens {
		addr, err := netip.ParseAddr(token)
		if err != nil {
			continue
		}
		addr = addr.Unmap()
		if addr.IsGlobalUnicast() && !addr.IsPrivate() && !sharedAddressSpace.Contains(addr) {
			return true
		}
	}
	return false
}
