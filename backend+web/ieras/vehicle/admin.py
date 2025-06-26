from django.contrib import admin

from vehicle.models import Ambulance
# Register your models here.

# Register your models here.@admin.register(Case)
@admin.register(Ambulance)
class EmergencyRequestAdmin(admin.ModelAdmin):
    list_display = ('id','driver', 'vehicle_number','ambulance_type', 'is_available')
