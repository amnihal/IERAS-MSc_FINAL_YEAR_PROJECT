from django.contrib import admin

from user.models import User

# Register your models here.

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ('id','name', 'email', 'contact','user_type', 'is_active',)
