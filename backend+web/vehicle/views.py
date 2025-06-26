from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.utils import timezone
from rest_framework import status
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from emergency.models import EmergencyRequest
from vehicle.models import Ambulance

@api_view(['POST'])
def accept_emergency_request(request):
    data = request.data
    try:
        case_id = data["case_id"]
        ambulance_id = data["ambulance_id"]

        case = EmergencyRequest.objects.get(id=case_id)
        ambulance = Ambulance.objects.get(id=ambulance_id)

        if case.status != 'pending':
            return Response({"error": "Case is not available for acceptance."}, status=400)

        if not ambulance.is_available:
            return Response({"error": "Ambulance is currently not available."}, status=400)

        # Assign ambulance and update status
        case.ambulance = ambulance
        case.status = 'accepted'
        case.update_time = timezone.now()
        case.save()

        ambulance.is_available = False
        ambulance.save()

        return Response({"message": "Emergency request accepted.", "case_id": case.id})

    except EmergencyRequest.DoesNotExist:
        return Response({"error": "Emergency request not found."}, status=404)
    except Ambulance.DoesNotExist:
        return Response({"error": "Ambulance not found."}, status=404)
    except Exception as e:
        return Response({"error": str(e)}, status=400)


@api_view(['GET'])
def get_ongoing_case(request, ambulance_id):
    try:

        ongoing_statuses = ['accepted', 'on_route', 'picked', 'to_hospital']
        
        case = EmergencyRequest.objects.filter(
            ambulance_id=ambulance_id,
            status__in=ongoing_statuses
        ).first()

        if case:
            hsp = case.hospital
            return Response({
                "case_id": case.id,
                "from_lat": case.from_lat,
                "from_long": case.from_long,
                "to_lat": case.hospital.latitude if hsp else None, 
                "to_long": case.hospital.longitude if hsp else None,
                "patient_condition": case.patient_condition,
                "description": case.description,
                "status": case.status,
                "patient_contact": case.user.contact, 
                "patient_name": case.user.name
            })
        else:
            return Response({"message": "No ongoing case"}, status=204)
    except Exception as e:
        return Response({"error": str(e)}, status=500)

    

@api_view(['POST'])
def update_case_status(request, case_id, status):
    try:
        case = EmergencyRequest.objects.get(id=case_id)
        case.status = status
        case.save()

        if status == "completed":
            ambulance = case.ambulance
            ambulance.is_available = True
            ambulance.save()

        return Response({"message": "Status updated"}, status=200)
    except EmergencyRequest.DoesNotExist:
        return Response({"error": "Case not found"}, status=404)


@api_view(['POST'])
def receive_ambulance_location(request):
    ambulance_id = request.data.get('ambulance_id')
    latitude = request.data.get('latitude')
    longitude = request.data.get('longitude')
    to_lat = request.data.get('to_lat')
    to_long = request.data.get('to_long')

    if not all([ambulance_id, latitude, longitude]):
        return Response({"error": "Missing data"}, status=status.HTTP_400_BAD_REQUEST)

    print(f"🚑 Ambulance {ambulance_id} is at ({latitude}, {longitude}) to ({to_lat},{to_long})")

    # Send to WebSocket group
    channel_layer = get_channel_layer()
    async_to_sync(channel_layer.group_send)(
        "normal_vehicle_group",
        {
            "type": "ambulance.location",
            "ambulance_id": ambulance_id,
            "latitude": latitude,
            "longitude": longitude,
            "to_lat": to_lat,
            "to_long": to_long,
        }
    )

    return Response({"message": "Location received and forwarded"}, status=status.HTTP_200_OK)


