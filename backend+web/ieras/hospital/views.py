from django.http import JsonResponse
from django.shortcuts import render, redirect, get_object_or_404
from django.views.decorators.http import require_GET
from hospital.models import Hospital
from emergency.models import EmergencyRequest
from .utils import get_eta_minutes
from user.models import User
from vehicle.models import Ambulance
from django.db.models import Q
from django.contrib import messages


# Create your views here.
@require_GET
def search_hospitals(request):
    query = request.GET.get('q', '')
    if len(query) < 2:
        return JsonResponse([], safe=False)  # Return empty list for short queries

    hospitals = Hospital.objects.filter(name__icontains=query)[:10]
    results = [{'name': hospital.name} for hospital in hospitals]
    return JsonResponse(results, safe=False)

# def hospital_dashboard(request):
#     return render(request, 'hospital.html')



def hospital_login(request):
    if request.method == "POST":
        username = request.POST.get("username")
        password = request.POST.get("password")
        hospital = Hospital.objects.filter(username=username, password=password).first()

        if hospital:
            request.session["hospital_id"] = hospital.id
            request.session["hospital_name"] = hospital.name
            return redirect("hospital_dashboard")
        else:
            messages.error(request, "Invalid username or password.")
    return render(request, "login.html", {'hide_sidebar': True})



def hospital_dashboard(request):
    hospital_id = request.session.get("hospital_id")

    if not hospital_id:
        messages.error(request, "Please log in to access the dashboard.")
        return redirect("hospital_login")
    
    hospital = Hospital.objects.get(id=hospital_id)
    total_ambulances = hospital.ambulances.count()
    ambulances_in_use = hospital.ambulances.filter(is_available=False).count()
    available_drivers = (User.objects.filter(ambulance__hospital=hospital).distinct().count())

    # Count cases handled by this hospital
    cases_handled = EmergencyRequest.objects.filter(hospital=hospital, status='completed').count()
    cases_pending = EmergencyRequest.objects.filter(hospital=hospital).exclude(status__in=['completed', 'cancelled']).count()

    context = {
        'hospital_name': hospital.name,
        'total_ambulances': total_ambulances,
        'ambulances_in_use': ambulances_in_use,
        'available_drivers': available_drivers,
        'cases_handled': cases_handled,
        'cases_pending': cases_pending,
    }

    return render(request, 'hospital.html', context)

from rest_framework.decorators import api_view
from rest_framework.response import Response
from emergency.models import EmergencyRequest
from emergency.serializers import EmergencyRequestSerializer

@api_view(['GET'])
def get_active_cases(request):
    hospital_id = request.session.get('hospital_id')
    if not hospital_id:
        messages.error(request, "Please log in to access the dashboard.")
        return redirect("hospital_login")
    active_cases = EmergencyRequest.objects.filter(status='picked', hospital_id=hospital_id)
    serializer = EmergencyRequestSerializer(active_cases, many=True)
    return Response(serializer.data)


def register_ambulance(request):
    hospital = request.session.get("hospital_id")
    hospital_id=request.session.get("hospital_id")
    if not hospital_id:
        messages.error(request, "Please log in to access the dashboard.")
        return redirect("hospital_login")
    
    hospital_obj = Hospital.objects.get(id=hospital)

    if request.method == 'POST':
        vehicle_number = request.POST.get('vehicle_number')
        ambulance_type = request.POST.get('ambulance_type')
        is_available = request.POST.get('is_available') == 'true'

        Ambulance.objects.create(
            driver=None,
            vehicle_number=vehicle_number,
            ambulance_type=ambulance_type,
            latitude=hospital_obj.latitude,
            longitude=hospital_obj.longitude,
            hospital=hospital_obj,
            is_available=is_available,
        )
        return redirect('register_ambulance')

    ambulances = Ambulance.objects.filter(hospital=hospital).select_related('driver')
    return render(request, 'register_ambulance.html', {
        'ambulances': ambulances,
    })


def register_driver(request):
    hospital_id = request.session.get("hospital_id")
    if not hospital_id:
        messages.error(request, "Please log in to access the dashboard.")
        return redirect("hospital_login")
    
    ambulances = Ambulance.objects.filter(hospital_id=hospital_id, driver__isnull=True)

    # Get drivers who have at least one ambulance from this hospital assigned
    drivers = User.objects.filter(
        ambulance__hospital_id=hospital_id
    ).distinct()

    if request.method == 'POST':
        name = request.POST.get('name')
        contact = request.POST.get('contact')
        email = request.POST.get('email')
        password = request.POST.get('password')
        ambulance_id = request.POST.get('ambulance')

        
        driver = User.objects.create(
            name=name, 
            contact=contact, 
            email=email,
            password=password,
            user_type='driver'
        )
        driver.save()

        # Assign ambulance if selected
        if ambulance_id:
            ambulance = Ambulance.objects.filter(id=ambulance_id, hospital_id=hospital_id).first()
            if ambulance:
                ambulance.driver = driver
                ambulance.save()

        return redirect('register_driver')  # reload the page to show updated list

    return render(request, 'register_driver.html', {
        'drivers': drivers,
        'ambulances': ambulances,
    })

def case_list(request):
    hospital_id = request.session.get("hospital_id")
    if not hospital_id:
        messages.error(request, "Please log in to access the dashboard.")
        return redirect("hospital_login")
    cases = EmergencyRequest.objects.filter(hospital_id=hospital_id).exclude(status='cancelled').select_related('user', 'ambulance').order_by('-request_time')
    return render(request, 'case_list.html', {'cases': cases})


# Update 
def update_ambulance(request, ambulance_id):
    ambulance = get_object_or_404(Ambulance, id=ambulance_id)

    if request.method == 'POST':
        ambulance.vehicle_number = request.POST.get('vehicle_number')
        ambulance.ambulance_type = request.POST.get('ambulance_type')
        ambulance.is_available = request.POST.get('is_available') == 'true'
        ambulance.save()
        return redirect('register_ambulance')

    return render(request, 'update_ambulance.html', {'ambulance': ambulance})

def update_driver(request, driver_id):
    hospital_id = request.session.get("hospital_id")
    if not hospital_id:
        messages.error(request, "Please log in to access the dashboard.")
        return redirect("hospital_login")
    
    driver = get_object_or_404(User, id=driver_id, user_type='driver')
    
    ambulances = Ambulance.objects.filter(hospital_id=hospital_id).filter(Q(driver__isnull=True) | Q(driver=driver))

    if request.method == 'POST':
        driver.name = request.POST.get('name')
        driver.contact = request.POST.get('contact')
        driver.email = request.POST.get('email')
        ambulance_id = request.POST.get('ambulance')

        # Unassign all ambulances from this driver
        Ambulance.objects.filter(driver=driver).update(driver=None)

        # Reassign new ambulance
        if ambulance_id:
            new_ambulance = Ambulance.objects.filter(id=ambulance_id, hospital_id=hospital_id).first()
            if new_ambulance:
                new_ambulance.driver = driver
                new_ambulance.save()

        driver.save()
        return redirect('register_driver')

    return render(request, 'update_driver.html', {
        'driver': driver,
        'ambulances': ambulances,
    })



# Delete 
def delete_ambulance(request, ambulance_id):
    ambulance = get_object_or_404(Ambulance, id=ambulance_id)
    ambulance.delete()
    return redirect('register_ambulance')


def delete_driver(request, driver_id):
    driver = get_object_or_404(User, id=driver_id, user_type='driver')
    driver.delete()
    return redirect('register_driver')

def hospital_logout(request):
    request.session.flush()  # Clears all session data
    return redirect('hospital_login')

