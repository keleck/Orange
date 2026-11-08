# 🚀 GitHub Actions Automation Documentation

## 🎉 Welcome

Congratulations! Your project has been successfully configured with GitHub Actions CI/CD pipeline for automated builds.

**[中文文档](README_CN.md)** | **English Documentation**

---

## 📚 Documentation Index

### 🚀 Getting Started

1. **[Setup Complete](SETUP_COMPLETE.md)** - Configuration summary
2. **[Quick Start Checklist](QUICK_START_CHECKLIST.md)** - Step-by-step setup guide
3. **[Workflows README](workflows/README.md)** - Workflow usage guide

### 📖 Guides

4. **[Release Guide](RELEASE_GUIDE.md)** - How to release new versions
5. **[Android Signing Guide](ANDROID_SIGNING_GUIDE.md)** - Configure app signing
6. **[Badges](BADGES.md)** - Add build status badges

### 🔧 Advanced

7. **[CI/CD Setup](CI_CD_SETUP.md)** - Complete technical documentation

### 🇨🇳 中文文档

8. **[快速开始](快速开始.md)** - 5-minute quick start (Chinese)
9. **[使用指南](使用指南.md)** - Detailed usage guide (Chinese)
10. **[文档中心](README_CN.md)** - Documentation center (Chinese)

---

## ⚡ Quick Start (3 Steps)

### Step 1: Update Version

Edit `pubspec.yaml`:

```yaml
version: 2.7.1+2025091116  # Change this
```

### Step 2: Push Tag

```bash
git tag v2.7.1
git push origin v2.7.1
```

### Step 3: Wait & Download

1. Visit **Actions** tab to watch progress
2. Wait 15-30 minutes for builds to complete
3. Visit **Releases** tab to download

---

## 📦 What You Get

After build completion, you'll have:

### Windows 🪟
- `fl_clash-windows-x64-portable.zip`

### Android 🤖
- `fl_clash-arm64-v8a-release.apk` ⭐ Recommended
- `fl_clash-armeabi-v7a-release.apk`
- `fl_clash-x86_64-release.apk`
- `fl_clash.aab` (Google Play)

### macOS 🍎
- `fl_clash-macos-universal.dmg`

---

## 📁 File Structure

```
.github/
├── workflows/
│   ├── build-multiplatform.yml   # Basic version
│   ├── build-advanced.yml        # Advanced with signing
│   ├── build-test.yml            # Quick test
│   └── README.md
│
├── README.md                      # This file
├── README_CN.md                   # Chinese docs center
├── SETUP_COMPLETE.md              # Setup summary
├── QUICK_START_CHECKLIST.md       # Checklist
├── RELEASE_GUIDE.md               # Release guide
├── ANDROID_SIGNING_GUIDE.md       # Android signing
├── BADGES.md                      # Badge config
├── CI_CD_SETUP.md                 # Complete docs
├── 快速开始.md                     # Chinese quick start
└── 使用指南.md                     # Chinese guide
```

---

## 🎯 Choose Your Path

### First Time User

1. Read [SETUP_COMPLETE.md](SETUP_COMPLETE.md)
2. Follow [QUICK_START_CHECKLIST.md](QUICK_START_CHECKLIST.md)
3. Run test build
4. Make your first release

### Regular User

- Keep this README bookmarked
- Use the 3-step quick start above
- Check [workflows/README.md](workflows/README.md) for details

### Advanced User

- Read [CI_CD_SETUP.md](CI_CD_SETUP.md) completely
- Configure Android signing with [ANDROID_SIGNING_GUIDE.md](ANDROID_SIGNING_GUIDE.md)
- Customize workflows as needed

---

## 🇨🇳 中文用户

**推荐从这里开始：**

1. **[快速开始](快速开始.md)** - 5分钟上手
2. **[使用指南](使用指南.md)** - 详细说明
3. **[文档中心](README_CN.md)** - 完整文档索引

---

## 🔍 Quick Reference

### Release New Version

```bash
# Update version in pubspec.yaml, then:
git tag v2.7.1
git push origin v2.7.1
```

### Test Build (Recommended First)

1. Go to **Actions** tab
2. Select **构建测试（快速验证）**
3. Click **Run workflow**
4. Select **all**

### Delete Wrong Tag

```bash
git tag -d v2.7.1
git push --delete origin v2.7.1
```

---

## 📊 Build Time

- **Windows**: ~5-8 minutes
- **Android**: ~8-12 minutes
- **macOS**: ~6-10 minutes
- **Total**: ~15-30 minutes (parallel)

---

## ❓ Common Issues

| Issue | Solution |
|-------|----------|
| Build failed? | Check Actions logs for details |
| No Release created? | Make sure tag starts with `v` |
| APK install error? | Download correct architecture (arm64-v8a) |

See [workflows/README.md](workflows/README.md) for more troubleshooting.

---

## 🎓 Learning Path

### Beginner (2 hours)

```
Setup Complete → Checklist → Test Build → First Release
```

### Advanced (4 hours)

```
Beginner Path → Android Signing → Workflow Customization
```

### Expert (Ongoing)

```
Advanced Path → Deep Dive Workflows → Performance Optimization
```

---

## 🌟 Features

✅ **Automated Builds** - Push tag, get releases  
✅ **Multi-Platform** - Windows, Android, macOS  
✅ **Code Signing** - Optional Android/macOS signing  
✅ **Auto Release** - Automatic GitHub Release creation  
✅ **Parallel Builds** - Fast concurrent building  
✅ **Comprehensive Docs** - 10 detailed guides  

---

## 📚 Documentation

| Document | Purpose | Reading Time |
|----------|---------|--------------|
| [Setup Complete](SETUP_COMPLETE.md) | Configuration summary | 5 min |
| [Quick Checklist](QUICK_START_CHECKLIST.md) | Step-by-step guide | 15 min |
| [Release Guide](RELEASE_GUIDE.md) | How to release | 8 min |
| [Android Signing](ANDROID_SIGNING_GUIDE.md) | Signing config | 20 min |
| [Badges](BADGES.md) | Status badges | 5 min |
| [CI/CD Setup](CI_CD_SETUP.md) | Complete docs | 30 min |
| [Workflows README](workflows/README.md) | Workflow details | 15 min |

---

## 🔐 Optional: Android Signing

To publish to Google Play or enable app updates:

1. Generate keystore
2. Convert to Base64
3. Add to GitHub Secrets
4. Rebuild

See [ANDROID_SIGNING_GUIDE.md](ANDROID_SIGNING_GUIDE.md) for details.

---

## 📛 Add Build Badge

In your `README.md`:

```markdown
[![Build Status](https://github.com/username/pages26-5-10A/actions/workflows/build-multiplatform.yml/badge.svg)](https://github.com/username/pages26-5-10A/actions)
```

More options in [BADGES.md](BADGES.md).

---

## 🤝 Contributing

Found an issue or have suggestions?

- Create an Issue
- Submit a Pull Request
- Share your experience

---

## 📄 License

MIT License - Free to use and modify.

---

## 🎊 Credits

Thanks to:
- [GitHub Actions](https://github.com/features/actions)
- [Flutter](https://flutter.dev)
- [subosito/flutter-action](https://github.com/subosito/flutter-action)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)

---

## 🎯 Next Steps

Ready to start?

1. **First time**: Read [SETUP_COMPLETE.md](SETUP_COMPLETE.md)
2. **Quick release**: Use the 3-step guide above
3. **Chinese user**: Start with [快速开始](快速开始.md)

---

## 📞 Need Help?

1. Check [workflows/README.md](workflows/README.md) FAQ
2. Read [CI_CD_SETUP.md](CI_CD_SETUP.md) troubleshooting
3. Check Actions logs for errors
4. Create an Issue on GitHub

---

**Happy Building!** 🚀

Remember the magic command:

```bash
git tag v2.7.1 && git push origin v2.7.1
```

Everything else is automated! ✨

---

**Version:** 1.0.0  
**Last Updated:** 2025-01-11  
**Supported Platforms:** Windows / Android / macOS
