#!/bin/bash
# iPhone에 Flutter 앱 실행 스크립트

echo "연결된 기기 확인 중..."
flutter devices

echo ""
echo "iPhone에 앱 실행 중..."
flutter run -d "00008030-001064E60A3B802E"


