from django.shortcuts import render
from user.models import User
from user.serializers import UserSerializer
from rest_framework.decorators import api_view
from rest_framework.response import Response
from vehicle.models import Ambulance
# Create your views here.

@api_view(['POST'])
def login_user(request):
    contact = request.data.get('contact')
    password = request.data.get('password')

    print(f"Received login request - contact: {contact}, password: {password}")
    try:
    
        user = User.objects.get(contact=contact)
        print(f"User found: {user}, password in DB: {user.password}")
        
        if password == user.password:
            # Password is correct, serialize and return user data
            serializer = UserSerializer(user)
            user_data = serializer.data

            if user.user_type == 'driver':
                try:
                    ambulance = Ambulance.objects.get(driver=user)
                    user_data['ambulance_id'] = ambulance.id
                    user_data['ambulance_type'] = ambulance.ambulance_type
                    print(f"Ambulance found for driver: {ambulance.id}")
                except Ambulance.DoesNotExist:
                    user_data['ambulance_id'] = None
                    user_data['ambulance_type'] = None
                    print("No ambulance found for driver")

            print(f"Sending user data: {user_data}")
            return Response(user_data)  # Returns user_id, user_type, etc.
        else:
            print("Invalid password provided")
            return Response({"error": "Invalid credentials"}, status=400)
    
    except User.DoesNotExist:
        print("User does not exist with provided contact")
        return Response({"error": "Invalid credentials"}, status=400)
    


@api_view(['POST'])
def register_user(request):
    data = request.data
    try:
        name = data['name']
        email = data['email']
        password = data['password']
        contact = data['contact']
        user_type = data.get('user_type', 'normal')  # default to 'normal'

        # Check if email or contact already exists
        if User.objects.filter(email=email).exists():
            return Response({'error': 'Email already registered'}, status=400)
        if User.objects.filter(contact=contact).exists():
            return Response({'error': 'Phone already registered'}, status=400)

        user = User.objects.create(
            name=name,
            email=email,
            password=password,  # raw, as requested
            contact=contact,
            user_type=user_type,
        )

        return Response({'message': 'User registered successfully!', 'user_id': user.id}, status=201)

    except KeyError as e:
        return Response({'error': f'Missing field: {str(e)}'}, status=400)
    except Exception as e:
        return Response({'error': str(e)}, status=400)