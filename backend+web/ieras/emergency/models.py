from django.db import models

from hospital.models import Hospital
from user.models import User
from vehicle.models import Ambulance

# Create your models here.

class EmergencyRequest(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE) 
    from_lat = models.DecimalField(max_digits=18, decimal_places=15)
    from_long = models.DecimalField(max_digits=18, decimal_places=15)
    hospital = models.ForeignKey(Hospital, on_delete=models.SET_NULL, null=True, blank=True)
    ambulance_type = models.CharField(max_length=20)
    ambulance = models.ForeignKey(Ambulance, on_delete=models.SET_NULL, null=True, blank=True)
    patient_condition = models.CharField(max_length=50)
    description = models.TextField(blank=True, null=True)
    request_time = models.DateTimeField(auto_now_add=True)
    update_time = models.DateTimeField(auto_now=True)
    status = models.CharField(max_length=20)
    
 
    def __str__(self):
        return f"Case {self.id} - {self.user.name} ({self.status})"