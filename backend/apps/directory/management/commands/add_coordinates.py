"""
Management command to add default coordinates for businesses
"""

from django.core.management.base import BaseCommand
from apps.directory.models import Business, Governorate, City, District
from decimal import Decimal


class Command(BaseCommand):
    help = 'Add default coordinates to businesses based on their location'
    
    # إحداثيات المحافظات المصرية الرئيسية
    GOVERNORATE_COORDS = {
        'Cairo': {'lat': 30.0444, 'lng': 31.2357},
        'Alexandria': {'lat': 31.2001, 'lng': 29.9187},
        'Giza': {'lat': 30.0131, 'lng': 31.2089},
        'Ismailia': {'lat': 30.5833, 'lng': 32.2667},
        'Port Said': {'lat': 31.2653, 'lng': 32.3019},
        'Suez': {'lat': 29.9668, 'lng': 32.5498},
        'Damietta': {'lat': 31.4165, 'lng': 31.8133},
        'Dakahlia': {'lat': 31.0409, 'lng': 31.3785},
        'Sharqia': {'lat': 30.5667, 'lng': 31.5000},
        'Qalyubia': {'lat': 30.1792, 'lng': 31.2117},
        'Kafr el-Sheikh': {'lat': 31.1107, 'lng': 30.9388},
        'Gharbia': {'lat': 30.8754, 'lng': 31.0335},
        'Monufia': {'lat': 30.5972, 'lng': 30.9876},
        'Beheira': {'lat': 30.8480, 'lng': 30.3436},
        'Faiyum': {'lat': 29.3084, 'lng': 30.8428},
        'Beni Suef': {'lat': 29.0661, 'lng': 31.0994},
        'Minya': {'lat': 28.0871, 'lng': 30.7618},
        'Asyut': {'lat': 27.1809, 'lng': 31.1837},
        'Sohag': {'lat': 26.5569, 'lng': 31.6948},
        'Qena': {'lat': 26.1551, 'lng': 32.7160},
        'Aswan': {'lat': 24.0889, 'lng': 32.8998},
        'Luxor': {'lat': 25.6872, 'lng': 32.6396},
        'Red Sea': {'lat': 27.2579, 'lng': 33.8116},
        'New Valley': {'lat': 25.4518, 'lng': 28.9870},
        'Matrouh': {'lat': 31.3543, 'lng': 27.2373},
        'North Sinai': {'lat': 31.1250, 'lng': 33.8500},
        'South Sinai': {'lat': 29.3117, 'lng': 34.4571},
    }
    
    def add_arguments(self, parser):
        parser.add_argument(
            '--update-all',
            action='store_true',
            help='Update coordinates for all businesses (including those with coordinates)',
        )
    
    def handle(self, *args, **options):
        update_all = options['update_all']
        
        if update_all:
            businesses = Business.objects.all()
        else:
            businesses = Business.objects.filter(
                latitude__isnull=True,
                longitude__isnull=True
            )
        
        updated_count = 0
        skipped_count = 0
        
        for business in businesses:
            try:
                # Get governorate name
                gov_name = business.district.city.governorate.name_en
                
                # Find coordinates
                coords = None
                for key, value in self.GOVERNORATE_COORDS.items():
                    if key.lower() in gov_name.lower() or gov_name.lower() in key.lower():
                        coords = value
                        break
                
                if coords:
                    # Add small random offset (0.01 to 0.05 degrees ~ 1-5 km)
                    import random
                    offset_lat = random.uniform(-0.05, 0.05)
                    offset_lng = random.uniform(-0.05, 0.05)
                    
                    business.latitude = Decimal(str(coords['lat'] + offset_lat))
                    business.longitude = Decimal(str(coords['lng'] + offset_lng))
                    business.save(update_fields=['latitude', 'longitude'])
                    
                    updated_count += 1
                    self.stdout.write(
                        self.style.SUCCESS(
                            f'✓ {business.name_en} - {gov_name}: '
                            f'{business.latitude}, {business.longitude}'
                        )
                    )
                else:
                    skipped_count += 1
                    self.stdout.write(
                        self.style.WARNING(
                            f'⚠ Skipped {business.name_en} - No coordinates for {gov_name}'
                        )
                    )
            
            except Exception as e:
                skipped_count += 1
                self.stdout.write(
                    self.style.ERROR(
                        f'✗ Error with {business.name_en}: {str(e)}'
                    )
                )
        
        self.stdout.write(
            self.style.SUCCESS(
                f'\n✅ Done! Updated: {updated_count}, Skipped: {skipped_count}'
            )
        )
