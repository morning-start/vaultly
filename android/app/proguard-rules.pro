# Vaultly - ProGuard / R8 混淆规则
# 保留 Flutter 引擎、插件及依赖库所需的类，防止 R8 误删

# ============================
# Flutter 引擎 (Engine)
# ============================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# ============================
# Flutter Secure Storage (JNI 加密层)
# ============================
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ============================
# Local Auth (生物识别)
# ============================
-keep class io.flutter.plugins.localauth.** { *; }

# ============================
# Google ML Kit (文字识别)
# ============================
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ============================
# Mobile Scanner (QR/条码)
# ============================
-keep class com.google.mlkit.vision.barcode.** { *; }

# ============================
# Google Play Services
# ============================
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ============================
# AndroidX
# ============================
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**

# ============================
# Kotlin
# ============================
-keep class kotlin.Metadata { *; }
-keep class kotlin.jvm.internal.** { *; }
-keep class kotlin.reflect.** { *; }
-dontwarn kotlin.**

# ============================
# 应用自身代码 (反射/序列化)
# ============================
-keep class com.example.vaultly.** { *; }

# ============================
# JNI 原生方法
# ============================
-keepclasseswithmembernames class * {
    native <methods>;
}

# ============================
# Parcelable 序列化
# ============================
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# ============================
# Serializable 序列化
# ============================
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ============================
# 枚举类
# ============================
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ============================
# 注解属性和元数据
# ============================
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Exceptions,InnerClasses,Signature,Deprecated,EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeInvisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations, RuntimeInvisibleParameterAnnotations
-keepattributes RuntimeVisibleTypeAnnotations, RuntimeInvisibleTypeAnnotations

# ============================
# 反射调用目标
# ============================
-keepclassmembers class * {
    @** *;
}

# ============================
# R$ 资源类
# ============================
-keep class **.R$* { *; }

# ============================
# 日志与调试
# ============================
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}