
from django.contrib import admin
from django.urls import path,include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('user/',include('user.urls')),
    path('',include('hospital.urls')),
    path('vehicle/',include('vehicle.urls')),
    path('emergency/',include('emergency.urls')),

]
