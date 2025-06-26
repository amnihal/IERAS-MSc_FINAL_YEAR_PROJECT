from django.db import models
from hospital.models import Hospital
from user.models import User



# Create your models here.

class Ambulance(models.Model):
    driver = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    vehicle_number = models.CharField(max_length=20, unique=True)
    ambulance_type = models.CharField(max_length=50)  # e.g., Basic, Advanced, Neonatal
    latitude = models.DecimalField(max_digits=18, decimal_places=15)
    longitude = models.DecimalField(max_digits=18, decimal_places=15)
    is_available = models.BooleanField(default=True)
    hospital = models.ForeignKey(Hospital, on_delete=models.CASCADE, related_name='ambulances')

    def __str__(self):
        return f"Ambulance {self.vehicle_number} - {self.ambulance_type}"
