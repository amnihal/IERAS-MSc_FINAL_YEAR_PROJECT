# 🆘 Intelligent Emergency Response and Assistance System (IERAS)

IERAS is an intelligent, real-time emergency response platform developed as part of an **M.Sc. Computer Science Final Year Project** designed to enhance ambulance dispatch, reduce response time, and facilitate better coordination between patients, ambulance drivers, hospitals, and nearby vehicles. It leverages modern mobile and web technologies to automate alerts, navigation, and emergency workflows.

---
## 🚀 Features

### 🔹 Emergency User App (Flutter)
- Raise emergency ambulance requests with location details.
- Track live ambulance movement and status (On Route → Picked → Completed).
- View nearby hospitals.
- Cancel request before pickup (if needed).
<p float="left">
  <img src="https://github.com/user-attachments/assets/0583f29e-f9b3-4498-ac4b-289aae6f0148" alt="Emergency User App" width="200"/>
  <img src="https://github.com/user-attachments/assets/6f4e348b-b6b4-4381-a407-f0f8404dff4f" alt="Emergency User App" width="200"/>
  <img src="https://github.com/user-attachments/assets/4ac7ce76-fe11-4988-a1bc-82679be9b2c6" alt="Emergency User App" width="200"/>
  <img src="https://github.com/user-attachments/assets/f96ee197-feb6-44bb-8684-08dce668ac3d" alt="Emergency User App" width="200"/>
</p>

### 🔹 Ambulance Driver App
- Receive real-time alerts via WebSocket.
- View live map with OSRM-based route to patient.
- Access patient contact and case details.
- Update case status (Start → Picked → Completed).
<p float="left">
  <img src="https://github.com/user-attachments/assets/955de1ce-49a7-4fc6-8c54-fb004019a1a6" alt="Ambulance Driver App" width="200"/>
  <img src="https://github.com/user-attachments/assets/47f385e0-6ada-444d-a77f-6167b18c2b63" alt="Ambulance Driver App" width="200"/>
  <img src="https://github.com/user-attachments/assets/f2dbb754-8601-481a-857f-dfb09bf0891e" alt="Ambulance Driver App" width="200"/>
</p>

### 🔹 Hospital Dashboard (Web – Django)
- Receive live incoming case alerts.
- Manage drivers and ambulances.
- Monitor emergency case history and ongoing operations.
<p float="left">
  <img src="https://github.com/user-attachments/assets/80e5432e-041d-4915-be21-f2255b084ff5" alt="Ambulance Driver App" width="400"/>
  <img src="https://github.com/user-attachments/assets/12a7d53a-3444-4bcb-ad03-003c5a0644e6" alt="Ambulance Driver App" width="400"/>
</p>
<p float="left">
  <img src="https://github.com/user-attachments/assets/0afa9015-01fc-4fc8-b089-d9c91239e65f" alt="Ambulance Driver App" width="400"/>
  <img src="https://github.com/user-attachments/assets/783d8f46-65bd-4915-9035-d6983596f1ca" alt="Ambulance Driver App" width="400"/>
</p>

### 🔹 Vehicle Alert System
- Nearby vehicles (unregistered) receive proximity alerts.
- Geofencing triggers route-clearance notifications to minimize siren usage.
<p float="left">
  <img src="https://github.com/user-attachments/assets/3ad79747-20a9-4943-b45b-71c576aa00c0" alt="Ambulance Driver App" width="800"/>
</p>

### 🔹 Admin Panel
- Built using Django Admin.
- Register hospitals, ambulances, drivers.
- Monitor system database and perform maintenance.

---

## 🛠️ Technologies Used

| Stack | Tech |
|-------|------|
| Frontend | Flutter, Html |
| Web Backend | Python, Django, Django REST Framework |
| Realtime | Django Channels (WebSocket), OSRM Routing |
| Database | SQLite / MySQL |
| Admin | Django Admin Panel |
| Hosting (optional) | Heroku, Firebase, or VPS |

---

## 🧱 Project Structure (Modules)

- `emergency_user_app/` – Flutter UI for users
- `driver_app/` – Flutter UI for ambulance drivers
- `hospital_dashboard/` – Web UI for hospitals
- `traffic_vehicle_app/` – Flutter UI for all normal vehicles
- `admin/` – Django admin interface

---


## 🚀 How to Run the Backend
This project uses Django for backend and Flutter for mobile/driver-side UI. To properly serve static files (like CSS) for the admin panel and run WebSocket-based features (like live ambulance alerts), follow the two-terminal setup below.

Run Django development server for admin panel and web frontend
```
python manage.py runserver
```
For flutter connection
```
daphne -b 0.0.0.0 -p 8000 ieras.asgi:application
```

Thank you 😊