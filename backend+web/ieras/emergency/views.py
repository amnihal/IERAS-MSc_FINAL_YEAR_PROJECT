from django.http import JsonResponse
from rest_framework.decorators import api_view
from rest_framework.response import Response
from emergency.models import EmergencyRequest
from hospital.models import Hospital
from user.models import User
from django.views.decorators.csrf import csrf_exempt
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from django.views.decorators.http import require_GET
    
@api_view(['POST'])
def create_case(request):
    data = request.data
    try:
        user = User.objects.get(id=data["user_id"])  # Fetch user
        hospital = None
        hospital_name = data.get("hospital_name")
        if hospital_name:
            try:
                hospital = Hospital.objects.get(name__iexact=hospital_name)
            except Hospital.DoesNotExist:
                return Response({"error": "Hospital not found"}, status=404)

        case = EmergencyRequest.objects.create(
            user=user,
            from_lat=data["from_lat"],
            from_long=data["from_long"],
            ambulance_type=data["ambulance_type"],
            patient_condition=data["patient_condition"],
            description=data.get("additional_notes", ""),
            hospital=hospital,
            status='pending',
        )

        # Broadcast to all connected ambulance drivers
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            "ambulance_broadcast",
            {
                "type": "send_emergency",
                "data": {
                    "case_id": case.id,
                    "from_lat": case.from_lat,
                    "from_long": case.from_long,
                    "patient_condition": case.patient_condition,
                    "ambulance_type": case.ambulance_type,
                    "hospital": {
                        "hname": case.hospital.name,
                        "hcontact": case.hospital.contact,
                        # "h_lat": case.hospital.latitude,
                        # "h_long": case.hospital.longitude
                        } if case.hospital else None,
                    
                }
            }
        )

        return Response({"message": "Ambulance request created!", "case_id": case.id}, status=201)

    except Exception as e:
        return Response({"error": str(e)}, status=400)
    


@api_view(['GET'])
def emergency_request_status(request, case_id):
    try:
        case = EmergencyRequest.objects.get(id=case_id)
        return Response({"status": case.status})
    except EmergencyRequest.DoesNotExist:
        return Response({"error": "Request not found"}, status=404)
    


@api_view(['GET'])
def check_user_ongoing_request(request, user_id):
    ongoing = EmergencyRequest.objects.filter(
        user_id=user_id,
        status__in=['pending', 'accepted', 'ongoing']
    ).order_by('-request_time').first()

    if ongoing:
        return Response({
            "ongoing": True,
            "case_id": ongoing.id,
            "status": ongoing.status
        })

    return Response({"ongoing": False})



@csrf_exempt
def cancel_request(request, request_id):
    if request.method == 'POST':
        try:
            emergency_request = EmergencyRequest.objects.get(id=request_id)

            if emergency_request.status in ['pending', 'requested']:
                emergency_request.status = 'cancelled'
                emergency_request.save()
                return JsonResponse({'success': True, 'message': 'Request cancelled'})
            else:
                return JsonResponse({'success': False, 'message': 'Cannot cancel this request at current stage'}, status=400)

        except EmergencyRequest.DoesNotExist:
            return JsonResponse({'success': False, 'message': 'Request not found'}, status=404)
    else:
        return JsonResponse({'success': False, 'message': 'Invalid request method'}, status=405)
    

@csrf_exempt
def emergency_request_status(request, case_id):
    try:
        emergency_request = EmergencyRequest.objects.get(pk=case_id)
    except EmergencyRequest.DoesNotExist:
        return JsonResponse({'error': 'Request not found'}, status=404)

    return JsonResponse({
        'caseId': emergency_request.pk,
        'status': emergency_request.status,  # e.g. 'requested', 'accepted', etc.
    })


@require_GET
def pending_requests(request):
    pending = EmergencyRequest.objects.filter(status='pending')
    data = [
        {
            "case_id": r.id,
            "from_lat": r.from_lat,
            "from_long": r.from_long,
            "patient_condition": r.patient_condition,
            "ambulance_type": r.ambulance_type,
            "hospital": {"name": r.hospital.name} if r.hospital else None,
            
        }
        for r in pending
    ]
    return JsonResponse(data, safe=False)