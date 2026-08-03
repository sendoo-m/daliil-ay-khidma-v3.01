"""Mobile-friendly query filters for the public API."""

from django_filters import rest_framework as filters

from apps.deals.models import Deal
from apps.directory.models import Business
from apps.products.models import Product


class BusinessFilter(filters.FilterSet):
    # Use NumberFilter instead of the implicit ModelChoiceFilter that
    # django-filters generates for ForeignKey fields listed in Meta.fields.
    # ModelChoiceFilter validates that the ID exists in the DB and raises
    # HTTP 400 when it doesn't – even for perfectly valid integers.  A plain
    # NumberFilter passes the value straight to the ORM and returns [] when
    # no rows match, which is the correct behaviour for a filter endpoint.
    category = filters.NumberFilter(field_name='category_id')
    governorate = filters.NumberFilter(field_name='district__city__governorate_id')
    city = filters.NumberFilter(field_name='district__city_id')
    min_rating = filters.NumberFilter(field_name='average_rating', lookup_expr='gte')

    class Meta:
        model = Business
        fields = [
            'business_type', 'district', 'governorate', 'city',
            'is_featured', 'min_rating',
        ]


class ProductFilter(filters.FilterSet):
    category = filters.NumberFilter(field_name='business__category_id')
    governorate = filters.NumberFilter(field_name='business__district__city__governorate_id')
    city = filters.NumberFilter(field_name='business__district__city_id')
    district = filters.NumberFilter(field_name='business__district_id')
    min_price = filters.NumberFilter(field_name='price', lookup_expr='gte')
    max_price = filters.NumberFilter(field_name='price', lookup_expr='lte')

    class Meta:
        model = Product
        fields = [
            'product_type', 'business', 'governorate', 'city',
            'district', 'is_featured', 'min_price', 'max_price',
        ]


class DealFilter(filters.FilterSet):
    category = filters.NumberFilter(field_name='business__category_id')
    governorate = filters.NumberFilter(field_name='business__district__city__governorate_id')
    city = filters.NumberFilter(field_name='business__district__city_id')
    district = filters.NumberFilter(field_name='business__district_id')

    class Meta:
        model = Deal
        fields = [
            'deal_type', 'business', 'governorate', 'city',
            'district', 'is_featured',
        ]
