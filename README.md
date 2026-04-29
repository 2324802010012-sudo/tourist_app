# 🌍 Tourist App - Nhận diện địa điểm du lịch Việt Nam

Ứng dụng sử dụng **Flutter + AI (TensorFlow)** để nhận diện các địa điểm du lịch tại Việt Nam thông qua hình ảnh.

---

# 🚀 Tính năng

* 📸 Chụp / chọn ảnh
* 🤖 Nhận diện địa điểm bằng AI
* 🌐 Gọi API backend để dự đoán
* 📊 Trả về tên địa điểm + độ chính xác

---

# 🧠 Công nghệ sử dụng

* Flutter (Mobile App)
* FastAPI (Backend)
* TensorFlow / Keras (Model AI)

---

# 📂 Cấu trúc project

```
backend/        # API xử lý model AI
models/         # Model đã train (.keras / .tflite)
lib/            # Code Flutter
assets/         # Ảnh, tài nguyên
```

---

# ⚙️ Yêu cầu hệ thống

## 🔹 Backend

* Python 3.9+
* pip

## 🔹 Mobile

* Flutter SDK
* Android Studio (hoặc VS Code)

---

# 📦 Cài đặt

## 1. Clone project

```bash
git clone https://github.com/2324802010012-sudo/tourist_app.git
cd tourist_app
```

---

## 2. Cài thư viện backend

```bash
pip install -r backend\requirements_backend.txt
```

---

## 3. Cài thư viện Flutter

```bash
flutter pub get
```

---

# 🚀 Cách chạy project

---

# 🖥️ Cách 1: Chạy bằng Emulator (Android Studio)

## Bước 1: Mở Emulator

* Mở Android Studio → Device Manager → Start emulator

## Bước 2: Chạy backend

```bash
uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

## Bước 3: Sửa URL API trong "lib\services\api_service.dart"

```dart
http://127.0.0.1:8000/docs
```

## Bước 4: Chạy app

```bash
flutter run
```

---

# 📱 Cách 2: Chạy bằng điện thoại thật

## Bước 1: Kết nối điện thoại

* Bật **USB Debugging**
* Kết nối với máy tính

## Bước 2: Chạy backend

```bash
uvicorn backend.api:app --host 0.0.0.0 --port 8000
```

## Bước 3: Lấy IP máy tính

```bash
ipconfig
```

Ví dụ:

```
192.168.1.5
```

## Bước 4: Sửa URL API trong "lib\services\api_service.dart"

```dart
http://192.168.1.5:8000/predict
```

## Bước 5: Chạy app

```bash
flutter run
```

---

# ⚠️ Lưu ý quan trọng

* 📶 Điện thoại và máy tính phải cùng WiFi
* 🔥 Không dùng `10.0.2.2` cho điện thoại thật
* 🧱 Nếu lỗi kết nối → kiểm tra firewall

---

# 🧪 Test API

Mở trình duyệt:

```
http://127.0.0.1:8000/docs
```

---

# 💥 Lỗi thường gặp

## ❌ Connection refused

👉 Backend chưa chạy

## ❌ Lost connection to device

👉 Emulator yếu → nên dùng máy thật

## ❌ Không load được model

👉 Kiểm tra đường dẫn trong `backend/api.py`

---

# 🎯 Kết luận

* Emulator → dễ test nhanh
* Điện thoại thật → ổn định, demo tốt hơn

---
