@echo off
echo Starting Spring Boot backend...
start cmd /k "cd hotel-backend && mvn spring-boot:run"

timeout /t 8 >nul

echo Starting Flutter frontend...
start cmd /k "cd hotel_booking_app && flutter pub get && flutter run"