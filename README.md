# 🌍 Tourist App - Nhận diện địa điểm du lịch Việt Nam

Ứng dụng sử dụng **Flutter + AI (TensorFlow)** để nhận diện các địa điểm du lịch tại Việt Nam thông qua hình ảnh.

---

# 🚀 Tính năng

* 📸 Chụp / chọn ảnh
* 🤖 Nhận diện địa điểm bằng AI
* 🌐 Gọi API backend để dự đoán
* 📊 Trả về tên địa điểm + độ chính xác
* 🎬 Tự động phát video giới thiệu sau khi nhận dạng thành công
* 🧠 Chỉ xác nhận địa điểm khi độ tin cậy từ 70% trở lên
* 🧭 Mở Google Maps để chỉ đường, tìm quán ăn và khách sạn gần địa điểm
* 🗣️ Trợ lý du lịch gợi ý điểm nổi bật, giờ tham quan, chi phí và tuyến kết hợp
* ❤️ Lưu yêu thích và lịch sử nhận dạng

---

# ✨ Điểm nâng cấp nổi bật

* Màn kết quả phục vụ trực tiếp khách du lịch: có video tự phát, badge độ tin cậy AI, ảnh thư viện, trợ lý du lịch, lịch trình nhanh và địa điểm liên quan.
* Khi AI dưới 70% độ tin cậy, app báo không nhận diện được và chỉ hiển thị địa điểm gần giống dưới dạng tham khảo.
* Backend `/predict` trả thêm `is_confident`, `recognized`, `confidence_threshold`, `top3` kèm thông tin địa điểm để app kiểm soát ngưỡng nhận diện rõ ràng.
* Model dữ liệu Flutter đã hỗ trợ lưu confidence, top matches và thời điểm nhận dạng vào lịch sử.

---

# 🧠 Công nghệ sử dụng

* Flutter (Mobile App)
* FastAPI (Backend)
* TensorFlow / Keras (Model AI)
* Firebase Auth
* MySQL (CSDL quan hệ cho backend)
* Shared Preferences
* url_launcher

---

# Cơ sở dữ liệu

Backend dùng MySQL và seed dữ liệu ban đầu từ `config/locations.json` khi khởi động.

Các biến môi trường backend dùng để kết nối MySQL:

```powershell
$env:MYSQL_HOST="127.0.0.1"
$env:MYSQL_PORT="3306"
$env:MYSQL_USER="root"
$env:MYSQL_PASSWORD="mat_khau_mysql"
$env:MYSQL_DATABASE="tourist_app"
```

Khi chạy lần đầu, backend sẽ tự tạo database `tourist_app` nếu tài khoản MySQL có quyền `CREATE DATABASE`. Nếu tài khoản không có quyền đó, hãy tạo database thủ công trước rồi giữ nguyên các biến môi trường trên.

Các bảng đã được tích hợp theo thiết kế CSDL:

* `users`, `user_preferences`
* `tourist_places`, `place_images`, `place_videos`, `travel_advices`, `nearby_services`
* `ai_models`
* `recognition_histories`, `recognition_candidates`, `favorite_places`, `recognition_feedbacks`

Những luồng đã dùng DB:

* đồng bộ tài khoản Firebase vào bảng `users`
* lấy địa điểm từ backend thay cho chỉ đọc JSON cục bộ
* lưu sở thích du lịch, yêu thích, lịch sử nhận dạng và phản hồi người dùng
* lưu top-3 candidate cho mỗi lần nhận dạng đã ghi lịch sử

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
* MySQL Server 8.x hoặc MariaDB tương thích MySQL

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

## 3. Cấu hình MySQL

```powershell
$env:MYSQL_HOST="127.0.0.1"
$env:MYSQL_PORT="3306"
$env:MYSQL_USER="root"
$env:MYSQL_PASSWORD="mat_khau_mysql"
$env:MYSQL_DATABASE="tourist_app"
```

---

## 4. Cài thư viện Flutter

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
uvicorn backend.main:app --host 0.0.0.0 --port 8000
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

Kiểm tra backend:

```
http://127.0.0.1:8000/health
```

Luồng demo đề xuất:

1. Chạy backend bằng `uvicorn backend.main:app --host 0.0.0.0 --port 8000`.
2. Mở app, chọn `Lens`, chụp hoặc chọn ảnh một địa điểm trong tập dữ liệu.
3. Trình bày kết quả từ 70% độ tin cậy trở lên, video tự phát, trợ lý du lịch, chỉ đường và lịch trình gợi ý.

---

# 💥 Lỗi thường gặp

## ❌ Connection refused

👉 Backend chưa chạy

## ❌ Lost connection to device

👉 Emulator yếu → nên dùng máy thật

## ❌ Không load được model

👉 Kiểm tra đường dẫn trong `backend/main.py`

---

# 🎯 Kết luận

* Emulator → dễ test nhanh
* Điện thoại thật → ổn định, demo tốt hơn

---
