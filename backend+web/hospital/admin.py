from django.contrib import admin

from hospital.models import Hospital

# Register your models here.

@admin.register(Hospital)
class HospitalAdmin(admin.ModelAdmin):
    list_display = ('id','name', 'contact')



admin.site.site_header = "IERAS"
admin.site.site_title = "Admin Portal"
admin.site.index_title = "Welcome to My Admin Portal"