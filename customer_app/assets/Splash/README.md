# 🎨 OGAS - Final Setup Guide

تصميم برتقالي حيوي مع اسطوانة واقعية مفصّلة.

## 📦 الملفات المرفقة

### أيقونة التطبيق
- `app_icon_1024.png` — للمتجر (App Store/Play Store)
- `app_icon_512.png` — Google Play Store الأساسي
- `app_icon_192.png` — Android xxxhdpi
- `app_icon_144.png` — Android xxhdpi
- `app_icon_96.png` — Android xhdpi
- `app_icon_72.png` — Android hdpi
- `app_icon_48.png` — Android mdpi

### شاشة السبلاش
- `splash_1080x1920.png` — Full HD (الأكثر شيوعاً)
- `splash_720x1280.png` — HD
- `splash_1440x2560.png` — QHD (هواتف عالية الدقة)

### ملفات SVG (للتعديل أو العرض داخل التطبيق)
- `ogas_app_icon.svg`
- `ogas_splash_screen.svg`

---

## 🚀 طريقة الإعداد السريع

### 1. ضع الملفات في المشروع
```
your_app/
├── assets/
│   └── icons/
│       ├── app_icon_1024.png
│       ├── app_icon_512.png
│       ├── splash_1080x1920.png
│       └── ogas_app_icon.svg
```

### 2. أضف للـ `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_svg: ^2.0.10+1

dev_dependencies:
  flutter_native_splash: ^2.4.1
  flutter_launcher_icons: ^0.14.1

flutter:
  assets:
    - assets/icons/

# ===== Splash Screen =====
flutter_native_splash:
  color: "#EA580C"
  image: assets/icons/app_icon_1024.png
  
  android_12:
    color: "#EA580C"
    image: assets/icons/app_icon_512.png
  
  ios: true
  android: true

# ===== App Icon =====
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icons/app_icon_1024.png"
  min_sdk_android: 21
  
  adaptive_icon_background: "#EA580C"
  adaptive_icon_foreground: "assets/icons/app_icon_512.png"
```

### 3. شغّل الأوامر:

```bash
flutter pub get
dart run flutter_native_splash:create
dart run flutter_launcher_icons
flutter clean && flutter pub get
```

---

## 🎨 شاشة Splash مخصصة (اختياري)

إذا تريد splash مع animation احترافي:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon container with subtle white card
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SvgPicture.asset(
                        'assets/icons/cylinder_white.svg',
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Brand name
                  const Text(
                    'OGAS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Arabic tagline
                  const Text(
                    'الغاز الموثوق',
                    style: TextStyle(
                      color: Color(0xFFFFEDD5),
                      fontSize: 18,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 🎨 ألوان البراند

```dart
class OgasColors {
  static const primary = Color(0xFFEA580C);       // الأساسي
  static const primaryLight = Color(0xFFFB923C);  // الفاتح
  static const primaryDark = Color(0xFF7C2D12);   // الداكن
  static const accent = Color(0xFFFCD34D);        // مميز
  static const surface = Color(0xFFFFEDD5);       // خلفية فاتحة
}
```

✅ **النتيجة:** تطبيق احترافي بهوية بصرية متكاملة!
