from django.db import models

# Create your models here.

class User(models.Model): 
    name = models.CharField(max_length=100)
    email = models.EmailField(unique=True)
    password = models.CharField(max_length=100)
    contact = models.CharField(max_length=15, unique=True)
    user_type = models.CharField(max_length=20)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name