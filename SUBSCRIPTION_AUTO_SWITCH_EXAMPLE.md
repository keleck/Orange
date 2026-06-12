# 订阅自动切换 API 使用示例

## 示例 1：基本使用（默认启用自动切换）

```dart
import 'package:fl_clash/xboard/features/subscription/services/subscription_downloader.dart';

Future<void> downloadSubscription() async {
  final url = 'https://api1.example.com/api/v2/subscription-encrypt/your-token-here';
  
  try {
    // 默认启用自动切换 API
    final profile = await SubscriptionDownloader.downloadSubscription(url);
    print('订阅下载成功: ${profile.label}');
  } catch (e) {
    print('订阅下载失败: $e');
  }
}
```

**预期行为**：
1. 首先尝试使用 `api1.example.com` 下载
2. 如果失败，自动切换到 `api2.example.com` 或其他配置的 API
3. 如果成功，返回 Profile 对象

## 示例 2：禁用自动切换（使用原有行为）

```dart
Future<void> downloadSubscriptionWithoutSwitch() async {
  final url = 'https://api1.example.com/api/v2/subscription-encrypt/your-token-here';
  
  try {
    // 禁用自动切换 API
    final profile = await SubscriptionDownloader.downloadSubscription(
      url,
      autoSwitchApi: false,
    );
    print('订阅下载成功: ${profile.label}');
  } catch (e) {
    print('订阅下载失败: $e');
  }
}
```

**预期行为**：
1. 仅尝试使用原始 URL 下载
2. 如果失败，直接抛出异常，不进行 API 切换

## 示例 3：结合并发竞速使用

```dart
Future<void> downloadWithRacing() async {
  final url = 'https://api1.example.com/api/v2/subscription-encrypt/your-token-here';
  
  try {
    // 启用并发竞速 + 自动切换 API
    final profile = await SubscriptionDownloader.downloadSubscription(
      url,
      enableRacing: true,    // 启用并发竞速（直连 + 代理）
      autoSwitchApi: true,   // 启用自动切换 API
    );
    print('订阅下载成功: ${profile.label}');
  } catch (e) {
    print('订阅下载失败: $e');
  }
}
```

**预期行为**：
1. 使用 `api1.example.com`，并发测试直连和所有代理
2. 如果所有方式都失败，自动切换到 `api2.example.com`
3. 再次并发测试直连和所有代理
4. 返回最快成功的结果

## 示例 4：在 ProfileImportService 中使用

```dart
// 在 lib/xboard/features/profile/services/profile_import_service.dart 中

Future<Profile> _downloadAndValidateProfile(String url) async {
  try {
    _logger.info('开始下载配置: ${UrlMasker.mask(url)}');
    
    // 使用 XBoard 订阅下载服务（自动启用 API 切换）
    final profile = await SubscriptionDownloader.downloadSubscription(
      url,
      enableRacing: true,
      autoSwitchApi: true,  // 自动切换 API
    ).timeout(
      downloadTimeout,
      onTimeout: () {
        throw TimeoutException('下载超时', downloadTimeout);
      },
    );
    
    _logger.info('配置下载和验证成功: ${profile.label ?? profile.id}');
    return profile;
    
  } catch (e) {
    _logger.error('配置下载失败: $e');
    rethrow;
  }
}
```

## 示例 5：配置多个 API 链接

在 `config.json` 中配置：

```json
{
  "subscription": {
    "urls": [
      {
        "url": "https://api1.example.com",
        "description": "主API服务器（美国）",
        "endpoints": {
          "v2": {
            "path": "/api/v2/subscription-encrypt/{token}",
            "requiresToken": true,
            "method": "GET",
            "description": "V2 加密订阅接口"
          }
        }
      },
      {
        "url": "https://api2.example.com",
        "description": "备用API服务器（欧洲）",
        "endpoints": {
          "v2": {
            "path": "/api/v2/subscription-encrypt/{token}",
            "requiresToken": true,
            "method": "GET",
            "description": "V2 加密订阅接口"
          }
        }
      },
      {
        "url": "https://api3.example.com",
        "description": "备用API服务器（亚洲）",
        "endpoints": {
          "v2": {
            "path": "/api/v2/subscription-encrypt/{token}",
            "requiresToken": true,
            "method": "GET",
            "description": "V2 加密订阅接口"
          }
        }
      },
      {
        "url": "http://192.168.1.100:7880",
        "description": "本地测试服务器",
        "endpoints": {
          "v2": {
            "path": "/api/v2/subscription-encrypt/{token}",
            "requiresToken": true,
            "method": "GET",
            "description": "V2 加密订阅接口"
          }
        }
      }
    ]
  }
}
```

## 示例 6：错误处理

```dart
Future<void> downloadWithErrorHandling() async {
  final url = 'https://api1.example.com/api/v2/subscription-encrypt/your-token-here';
  
  try {
    final profile = await SubscriptionDownloader.downloadSubscription(url);
    print('✅ 订阅下载成功: ${profile.label}');
    print('📊 节点数量: ${profile.proxies?.length ?? 0}');
    print('📅 更新时间: ${profile.lastUpdateDate}');
    
  } on TimeoutException catch (e) {
    print('⏱️ 下载超时: ${e.message}');
    // 可以提示用户检查网络连接
    
  } on SocketException catch (e) {
    print('🌐 网络连接失败: ${e.message}');
    // 可以提示用户检查网络设置
    
  } on HttpException catch (e) {
    print('🔴 HTTP 请求失败: ${e.message}');
    // 可以提示用户联系服务提供商
    
  } catch (e) {
    if (e.toString().contains('所有API链接都下载失败')) {
      print('❌ 所有 API 都无法访问，请稍后重试');
      // 可以提示用户检查订阅链接或联系客服
    } else {
      print('❌ 订阅下载失败: $e');
    }
  }
}
```

## 示例 7：监听下载进度（结合 ProfileImportService）

```dart
Future<void> importSubscriptionWithProgress() async {
  final url = 'https://api1.example.com/api/v2/subscription-encrypt/your-token-here';
  
  final importService = XBoardProfileImportService(ref);
  
  final result = await importService.importSubscription(
    url,
    onProgress: (status, progress, message) {
      print('[$status] ${(progress * 100).toInt()}% - $message');
      
      // 可以在这里更新 UI 进度条
      if (message?.contains('切换到其他API') ?? false) {
        print('🔄 正在尝试备用 API...');
      }
    },
  );
  
  if (result.isSuccess) {
    print('✅ 导入成功！');
    print('📊 Profile: ${result.profile?.label}');
    print('⏱️ 耗时: ${result.duration?.inMilliseconds}ms');
  } else {
    print('❌ 导入失败: ${result.errorMessage}');
    print('🔍 错误类型: ${result.errorType}');
  }
}
```

## 测试场景

### 场景 1：主 API 正常
```
输入: https://api1.example.com/api/v2/subscription-encrypt/abc123
结果: 直接从 api1 下载成功，不触发 API 切换
日志: [INFO] ✅ 订阅下载成功: MySubscription
```

### 场景 2：主 API 失败，备用 API 成功
```
输入: https://api1.example.com/api/v2/subscription-encrypt/abc123
结果: api1 失败后自动切换到 api2，下载成功
日志: 
  [WARNING] 使用当前URL下载失败: HTTP 503
  [INFO] 🔄 开始尝试切换到其他API链接...
  [INFO] ✅ 选择备用API: 备用API服务器（欧洲）
  [INFO] ✅ 订阅下载成功: MySubscription
```

### 场景 3：所有 API 都失败
```
输入: https://api1.example.com/api/v2/subscription-encrypt/abc123
结果: 所有 API 都失败，抛出异常
日志:
  [WARNING] 使用当前URL下载失败: HTTP 503
  [INFO] 🔄 开始尝试切换到其他API链接...
  [ERROR] 使用备用API下载也失败: HTTP 503
  Exception: 所有API链接都下载失败。原始错误: HTTP 503, 备用API错误: HTTP 503
```

### 场景 4：无法提取 Token
```
输入: https://api1.example.com/invalid-url
结果: 无法提取 token，不触发 API 切换
日志:
  [WARNING] 使用当前URL下载失败: Invalid URL
  [WARNING] 无法从URL中提取token
  [WARNING] ⚠️ 没有找到可用的备用API链接
  Exception: Invalid URL
```

## 性能对比

| 场景 | 不启用自动切换 | 启用自动切换 |
|------|--------------|------------|
| 主 API 正常 | 2-5秒 | 2-5秒（无额外开销） |
| 主 API 失败 | 立即失败 | 4-10秒（自动重试备用 API） |
| 所有 API 失败 | 立即失败 | 8-15秒（尝试所有 API） |

## 最佳实践

1. **配置多个地理位置分散的 API**：提高全球用户的访问成功率
2. **保持日志级别为 INFO**：便于追踪 API 切换情况
3. **结合重试机制使用**：在 ProfileImportService 中配合使用
4. **监控 API 健康状态**：定期检查各个 API 的可用性
5. **提供用户反馈**：在 UI 中显示 API 切换状态

## 常见问题

**Q: 自动切换会增加下载时间吗？**
A: 仅在主 API 失败时才会触发切换，成功下载不会有额外开销。

**Q: 可以指定优先使用哪个 API 吗？**
A: 当前版本按配置文件顺序选择，未来版本会支持优先级配置。

**Q: 支持循环尝试所有 API 吗？**
A: 当前版本仅尝试一次备用 API，未来版本会支持循环尝试。

**Q: 如何禁用自动切换？**
A: 设置 `autoSwitchApi: false` 参数即可。

**Q: 自动切换支持所有订阅类型吗？**
A: 是的，支持普通订阅和加密订阅。
