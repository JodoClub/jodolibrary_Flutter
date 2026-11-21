# Jodo Library — Maestro E2E Testing Guide (Free & Open-Source)

This directory contains automated End-to-End (E2E) UI test flows for the Jodo Library Flutter mobile app using [Maestro](https://maestro.mobile.dev).

---

## 📁 Test Flows Included

1. **`01_owner_flow.yaml`**:
   - Welcome Screen ➔ Library Owner Login ➔ Enter Mobile
   - OTP Verification with Universal Dev OTP (`4321`)
   - Library Setup (Owner Name, Library Name, Address, Capacity)
   - Partner Dashboard KPIs & Workspace Verification
   - Dynamic 2-Minute Attendance QR & Rolling Passcode Verification
   - Profile Navigation & Logout Test

2. **`02_student_flow.yaml`**:
   - Welcome Screen ➔ Student Login ➔ Enter Mobile
   - OTP Verification (`4321`)
   - Student Setup (Full Name, Emergency Contact, Target Exam)
   - Student Dashboard (Attendance & Productivity sections)
   - Explore Spaces ("Other Library spaces")
   - Attendance Scanner & Dynamic 6-digit Passcode Modal
   - Profile Navigation & Logout Test

---

## 🚀 How to Run Tests

### Option 1: Double-Click Batch File (Easiest)
Just double-click:
```
run_maestro_tests.bat
```
*(Make sure your Android device is connected via USB or an Android Emulator is running).*

### Option 2: Run from Terminal / PowerShell
```powershell
# Run all test flows
maestro test .maestro/

# Run only the Owner flow
maestro test .maestro/01_owner_flow.yaml

# Run only the Student flow
maestro test .maestro/02_student_flow.yaml
```

---

## 🎨 Interactive Visual Debugging: Maestro Studio
Maestro has a built-in visual interactive inspector:
```powershell
maestro studio
```
This opens a web dashboard at `http://localhost:9999` mirroring your phone screen in real time. You can click on any button or input to copy its exact selector directly into your YAML files!
