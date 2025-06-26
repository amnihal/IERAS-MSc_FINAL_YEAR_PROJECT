from django.contrib import admin

from emergency.models import EmergencyRequest

# Register your models here.@admin.register(Case)
@admin.register(EmergencyRequest)
class EmergencyRequestAdmin(admin.ModelAdmin):
    list_display = ('id','user', 'ambulance','patient_condition', 'status', 'request_time', 'update_time')