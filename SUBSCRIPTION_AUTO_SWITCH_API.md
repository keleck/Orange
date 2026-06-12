# 订阅下载自动切换 API 功能

## 功能概述

当订阅下载失败时，系统会自动尝试切换到其他可用的 API 链接重新下载订阅，提高订阅下载的成功率和可靠性。

## 功能特性

### 1. 自动 API 切换
- 当使用当前 API 链接下载订阅失败时，自动从配置文件中选择另一个可用的 API 链接
- 智能跳过与当前 API 相同的链接，避免重复尝试
- 支持多个备用 API 链接配置

### 2. Token 自动提取
- 自动从失败的订阅 URL 中提取用户 token
- 使用提取的 token 构建新的订阅 URL

### 3. 详细日志记录
- 记录 API 切换过程的每一步
- 显示当前使用的 API 和备用 API 信息
- 便于问题排查和调试

## 使用方法

### 代码调用

```dart
// 默认启用自动切换 API
final profile = await SubscriptionDownloader.downloadSubscription(
  url,
  enableRacing: true,
  autoSwitchApi: true,  // 默认为 true
);

// 禁用自动切换 API（使用原有行为）
final profile = await SubscriptionDownloader.downloadSubscription(
  url,
  enableRacing: true,
  autoSwitchApi: false,
);
```

### 配置文件设置

在 `config.json` 中配置多个订阅 API 链接：

```json
{
  "subscription": {
    "urls": [
      {
        "url": "https://api1.example.com",
        "description": "主API服务器",
        "endpoints": {
          "v2": {
            "path": "/api/v2/subscription-encrypt/{token}",
            "requiresToken": true,
            "method": "GET"
          }
        }
      },
      {
        "url": "https://api2.example.com",
        "description": "备用API服务器1",
        "endpoints": {
          "v2": {
            "path": "/api/v2/subscription-encrypt/{token}",
            "requiresToken": true,
            "method": "GET"
          }
        }
      },
      {
        "url": "https://api3.example.com",
        "description": "备用API服务器2",
        "endpoints": {
          "v2": {
            "path": "/api/v2/subscription-encrypt/{token}",
            "requiresToken": true,
            "method": "GET"
          }
        }
      }
    ]
  }
}
```

## 工作流程

1. **首次尝试**：使用原始 URL 下载订阅
   - 如果成功，直接返回结果
   - 如果失败，进入步骤 2

2. **API 切换**：
   - 从原始 URL 中提取用户 token
   - 从配置文件中获取所有订阅 API 链接
   - 选择一个与当前 API 不同的链接
   - 使用提取的 token 构建新的订阅 URL

3. **重新下载**：使用新的 API 链接重新下载订阅
   - 如果成功，返回结果
   - 如果失败，抛出包含两次错误信息的异常

## 日志示例

```
[INFO] 开始下载订阅: https://api1.*****.com/api/v2/subscription-encrypt/abc***xyz
[WARNING] 使用当前URL下载失败: Exception: HTTP 503
[INFO] 🔄 开始尝试切换到其他API链接...
[INFO] 找到 3 个订阅API配置
[DEBUG] 跳过当前API: 主API服务器
[INFO] ✅ 选择备用API: 备用API服务器1 - https://api2.*****.com/api/v2/subscription-encrypt/abc***xyz
[INFO] 🔄 使用备用API重新下载订阅...
[INFO] 开始并发下载 (3种方式)
[INFO] 🏆 直连 获胜！
[INFO] ✅ 订阅下载成功: MySubscription
```

## 错误处理

### 场景 1：无法提取 Token
```
[WARNING] 无法从URL中提取token: https://*****.com/invalid-url
[WARNING] ⚠️ 没有找到可用的备用API链接
```
系统会抛出原始错误，不进行 API 切换。

### 场景 2：配置中没有备用 API
```
[WARNING] 配置中没有订阅API链接
[WARNING] ⚠️ 没有找到可用的备用API链接
```
系统会抛出原始错误。

### 场景 3：所有 API 都失败
```
[ERROR] 使用备用API下载也失败: Exception: HTTP 503
Exception: 所有API链接都下载失败。原始错误: Exception: HTTP 503, 备用API错误: Exception: HTTP 503
```
系统会抛出包含两次错误信息的异常。

## 兼容性

- ✅ 完全向后兼容，默认启用自动切换功能
- ✅ 可通过 `autoSwitchApi: false` 禁用，恢复原有行为
- ✅ 不影响现有的并发竞速功能
- ✅ 支持所有订阅端点类型（v2、v1 等）

## 性能影响

- 仅在首次下载失败时才会触发 API 切换
- 切换过程几乎无延迟（仅需解析配置和构建 URL）
- 不会增加成功下载的时间开销

## 注意事项

1. **配置要求**：确保 `config.json` 中配置了多个订阅 API 链接
2. **Token 格式**：系统会自动从 URL 中提取 token，支持常见的订阅 URL 格式
3. **端点类型**：当前默认使用 `v2` 端点，如需支持其他端点类型，可修改代码
4. **日志级别**：建议在生产环境中保持日志级别为 INFO 或更高，以便追踪 API 切换情况

## 未来改进

- [ ] 支持自定义端点类型选择策略
- [ ] 支持 API 健康检查和优先级排序
- [ ] 支持更多的 URL 格式和 token 提取方式
- [ ] 添加 API 切换统计和监控
- [ ] 支持循环尝试所有可用的 API 链接

## 相关文件

- `lib/xboard/features/subscription/services/subscription_downloader.dart` - 订阅下载服务
- `lib/xboard/features/subscription/utils/subscription_url_helper.dart` - URL 辅助工具
- `lib/xboard/config/xboard_config.dart` - 配置管理
- `config.json` - 订阅 API 配置文件
