from django.urls import path
from . import views


urlpatterns = [
    path('request-ambulance/',views.create_case),
    path('emergency_request_status/<int:case_id>/', views.emergency_request_status),
    path('check_ongoing_request/<int:user_id>/', views.check_user_ongoing_request),
    path('cancel_request/<int:request_id>/', views.cancel_request),
    path('emergency_request_status/<int:case_id>/', views.emergency_request_status),
    path('pending-requests/', views.pending_requests),

    
]
