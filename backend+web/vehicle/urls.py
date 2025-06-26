
from django.urls import path
from . import views

urlpatterns = [
    path('accept_request/', views.accept_emergency_request),
    path('ongoing-case/<int:ambulance_id>/', views.get_ongoing_case),
    path('update_case_status/<int:case_id>/<str:status>/', views.update_case_status),
    path('ambulance/update-location/', views.receive_ambulance_location),
]
