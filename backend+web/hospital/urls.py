
from django.contrib import admin
from django.urls import path
from . import views

urlpatterns = [
    path('hospital/search_hospital/', views.search_hospitals),
    path('', views.hospital_dashboard, name='hospital_dashboard'),
    path('register-ambulance/', views.register_ambulance, name='register_ambulance'),
    path('register-driver/', views.register_driver, name='register_driver'),
    path('case-list/', views.case_list, name='case_list'),
    path('update-ambulance/<int:ambulance_id>/', views.update_ambulance, name='update_ambulance'),
    path('delete-ambulance/<int:ambulance_id>/', views.delete_ambulance, name='delete_ambulance'),
    path('delete-driver/<int:driver_id>/', views.delete_driver, name='delete_driver'),
    path('update-driver/<int:driver_id>/', views.update_driver, name='update_driver'),
    path('login/', views.hospital_login, name='hospital_login'),
    path('logout/', views.hospital_logout, name='hospital_logout'),
    path('api/active-cases/', views.get_active_cases, name='active_cases'),


]

