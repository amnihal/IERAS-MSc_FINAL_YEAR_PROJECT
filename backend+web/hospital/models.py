from django.db import models

# Create your models here.

class Hospital(models.Model):
    name = models.CharField(max_length=100)
    username = models.CharField(unique=True, max_length=100)
    password = models.CharField(max_length=45)
    contact = models.CharField(max_length=15)
    latitude = models.DecimalField(max_digits=18, decimal_places=15)
    longitude = models.DecimalField(max_digits=18, decimal_places=15)
    
    def __str__(self):
        return self.name