from django import forms
from django.contrib.auth.forms import UserCreationForm

from apps.accounts.models import User
from apps.categories.models import Category
from apps.deals.models import Deal
from apps.directory.models import Business
from apps.directory.models.location import City, District, Governorate
from apps.products.models import Product


# ========================================
# USER FORMS
# ========================================

class UserProfileForm(forms.ModelForm):
    class Meta:
        model = User
        fields = ['first_name', 'last_name', 'email']
        widgets = {
            'first_name': forms.TextInput(attrs={'class': 'form-control'}),
            'last_name':  forms.TextInput(attrs={'class': 'form-control'}),
            'email':      forms.EmailInput(attrs={'class': 'form-control'}),
        }


class AdminUserCreateForm(UserCreationForm):
    email      = forms.EmailField(required=True)
    first_name = forms.CharField(max_length=150, required=False)
    last_name  = forms.CharField(max_length=150, required=False)
    is_staff   = forms.BooleanField(required=False, label='مشرف')
    is_active  = forms.BooleanField(required=False, initial=True, label='فعّال')

    class Meta:
        model  = User
        fields = ('username', 'email', 'first_name', 'last_name', 'is_staff', 'is_active')


class AdminUserEditForm(forms.ModelForm):
    class Meta:
        model  = User
        fields = ('username', 'email', 'first_name', 'last_name', 'is_staff', 'is_active')
        widgets = {
            'username':   forms.TextInput(attrs={'class': 'form-control'}),
            'email':      forms.EmailInput(attrs={'class': 'form-control'}),
            'first_name': forms.TextInput(attrs={'class': 'form-control'}),
            'last_name':  forms.TextInput(attrs={'class': 'form-control'}),
        }


# ========================================
# BUSINESS FORM
# ========================================

class AdminBusinessForm(forms.ModelForm):
    governorate = forms.ModelChoiceField(
        queryset=Governorate.objects.filter(is_active=True).order_by('name_ar'),
        required=False,
        label='المحافظة',
        widget=forms.Select(attrs={'class': 'form-select select2', 'id': 'id_governorate'}),
    )
    city = forms.ModelChoiceField(
        queryset=City.objects.none(),
        required=False,
        label='المدينة',
        widget=forms.Select(attrs={'class': 'form-select select2', 'id': 'id_city'}),
    )

    class Meta:
        model  = Business
        fields = [
            'name_en', 'name_ar',
            'description_en', 'description_ar',
            'category', 'business_type',
            'governorate', 'city', 'district',
            'email', 'phone', 'whatsapp', 'website',
            'address_ar', 'address_en',
            'logo', 'cover_image',
            'is_active', 'is_verified', 'is_featured',
            'latitude', 'longitude',
            'working_hours_ar', 'working_hours_en',
            'facebook', 'instagram', 'twitter', 'tiktok',
            'location_url',
        ]
        widgets = {
            'name_en':          forms.TextInput(attrs={'class': 'form-control'}),
            'name_ar':          forms.TextInput(attrs={'class': 'form-control'}),
            'description_en':   forms.Textarea(attrs={'class': 'form-control', 'rows': 4}),
            'description_ar':   forms.Textarea(attrs={'class': 'form-control', 'rows': 4}),
            'category':         forms.Select(attrs={'class': 'form-select select2'}),
            'business_type':    forms.Select(attrs={'class': 'form-select'}),
            'district':         forms.Select(attrs={'class': 'form-select select2', 'id': 'id_district'}),
            'email':            forms.EmailInput(attrs={'class': 'form-control'}),
            'phone':            forms.TextInput(attrs={'class': 'form-control'}),
            'whatsapp':         forms.TextInput(attrs={'class': 'form-control'}),
            'website':          forms.URLInput(attrs={'class': 'form-control'}),
            'address_ar':       forms.TextInput(attrs={'class': 'form-control'}),
            'address_en':       forms.TextInput(attrs={'class': 'form-control'}),
            'latitude':         forms.NumberInput(attrs={'class': 'form-control', 'step': 'any'}),
            'longitude':        forms.NumberInput(attrs={'class': 'form-control', 'step': 'any'}),
            'working_hours_ar': forms.TextInput(attrs={'class': 'form-control'}),
            'working_hours_en': forms.TextInput(attrs={'class': 'form-control'}),
            'facebook':         forms.URLInput(attrs={'class': 'form-control'}),
            'instagram':        forms.URLInput(attrs={'class': 'form-control'}),
            'twitter':          forms.URLInput(attrs={'class': 'form-control'}),
            'tiktok':           forms.URLInput(attrs={'class': 'form-control'}),
            'location_url':     forms.URLInput(attrs={'class': 'form-control'}),
            'is_active':        forms.CheckboxInput(attrs={'class': 'form-check-input'}),
            'is_verified':      forms.CheckboxInput(attrs={'class': 'form-check-input'}),
            'is_featured':      forms.CheckboxInput(attrs={'class': 'form-check-input'}),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.instance.pk and self.instance.district:
            try:
                city = self.instance.district.city
                gov  = city.governorate
                self.fields['governorate'].initial = gov
                self.fields['city'].initial        = city
                self.fields['city'].queryset       = City.objects.filter(governorate=gov, is_active=True).order_by('name_ar')
                self.fields['district'].queryset   = District.objects.filter(city=city, is_active=True).order_by('name_ar')
            except AttributeError:
                pass
        if self.is_bound:
            if self.data.get('governorate'):
                try:
                    self.fields['city'].queryset = City.objects.filter(
                        governorate_id=int(self.data['governorate']), is_active=True
                    ).order_by('name_ar')
                except (ValueError, TypeError):
                    pass
            if self.data.get('city'):
                try:
                    self.fields['district'].queryset = District.objects.filter(
                        city_id=int(self.data['city']), is_active=True
                    ).order_by('name_ar')
                except (ValueError, TypeError):
                    pass


# ========================================
# PRODUCT FORM
# ========================================

def _product_fields():
    allowed = [
        'name_en', 'name_ar',
        'description_en', 'description_ar',
        'product_type', 'price', 'ProductImage',
        'is_available', 'is_featured',
    ]
    existing = {f.name for f in Product._meta.get_fields() if hasattr(f, 'name')}
    return [f for f in allowed if f in existing]


class AdminProductForm(forms.ModelForm):
    class Meta:
        model   = Product
        fields  = _product_fields()
        widgets = {
            'name_en':        forms.TextInput(attrs={'class': 'form-control'}),
            'name_ar':        forms.TextInput(attrs={'class': 'form-control'}),
            'description_en': forms.Textarea(attrs={'class': 'form-control', 'rows': 4}),
            'description_ar': forms.Textarea(attrs={'class': 'form-control', 'rows': 4}),
            'product_type':   forms.Select(attrs={'class': 'form-select'}),
            'price':          forms.NumberInput(attrs={'class': 'form-control', 'step': '0.01'}),
        }


# ========================================
# DEAL FORM
# ========================================

def _deal_fields():
    allowed = [
        'title_en', 'title_ar',
        'description_en', 'description_ar',
        'deal_type',
        'discount_percentage', 'discount_amount',
        'original_price', 'final_price',
        'start_date', 'end_date',
        'terms_en', 'terms_ar',
        'image', 'max_uses', 'max_uses_per_user',
        'is_active', 'is_featured',
    ]
    existing = {f.name for f in Deal._meta.get_fields() if hasattr(f, 'name')}
    return [f for f in allowed if f in existing]


class AdminDealForm(forms.ModelForm):
    class Meta:
        model   = Deal
        fields  = _deal_fields()
        widgets = {
            'title_en':            forms.TextInput(attrs={'class': 'form-control'}),
            'title_ar':            forms.TextInput(attrs={'class': 'form-control'}),
            'description_en':      forms.Textarea(attrs={'class': 'form-control', 'rows': 4}),
            'description_ar':      forms.Textarea(attrs={'class': 'form-control', 'rows': 4}),
            'deal_type':           forms.Select(attrs={'class': 'form-select'}),
            'discount_percentage': forms.NumberInput(attrs={'class': 'form-control'}),
            'discount_amount':     forms.NumberInput(attrs={'class': 'form-control', 'step': '0.01'}),
            'original_price':      forms.NumberInput(attrs={'class': 'form-control', 'step': '0.01'}),
            'final_price':         forms.NumberInput(attrs={'class': 'form-control', 'step': '0.01'}),
            'start_date':          forms.DateTimeInput(attrs={'class': 'form-control', 'type': 'datetime-local'}),
            'end_date':            forms.DateTimeInput(attrs={'class': 'form-control', 'type': 'datetime-local'}),
            'terms_en':            forms.Textarea(attrs={'class': 'form-control', 'rows': 3}),
            'terms_ar':            forms.Textarea(attrs={'class': 'form-control', 'rows': 3}),
            'max_uses':            forms.NumberInput(attrs={'class': 'form-control'}),
            'max_uses_per_user':   forms.NumberInput(attrs={'class': 'form-control'}),
        }


# ========================================
# CATEGORY FORM
# ========================================

def _category_fields():
    allowed = [
        'name_en', 'name_ar',
        'description_en', 'description_ar',
        'parent', 'icon', 'ProductImage',
        'order', 'is_active',
        'meta_keywords_en', 'meta_keywords_ar',
    ]
    existing = {f.name for f in Category._meta.get_fields() if hasattr(f, 'name')}
    return [f for f in allowed if f in existing]


class CategoryForm(forms.ModelForm):
    class Meta:
        model   = Category
        fields  = _category_fields()
        widgets = {
            'name_en':          forms.TextInput(attrs={'class': 'form-control'}),
            'name_ar':          forms.TextInput(attrs={'class': 'form-control'}),
            'description_en':   forms.Textarea(attrs={'class': 'form-control', 'rows': 3}),
            'description_ar':   forms.Textarea(attrs={'class': 'form-control', 'rows': 3}),
            'parent':           forms.Select(attrs={'class': 'form-select'}),
            'icon':             forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'fas fa-store'}),
            'order':            forms.NumberInput(attrs={'class': 'form-control'}),
            'is_active':        forms.CheckboxInput(attrs={'class': 'form-check-input'}),
            'meta_keywords_en': forms.TextInput(attrs={'class': 'form-control'}),
            'meta_keywords_ar': forms.TextInput(attrs={'class': 'form-control'}),
        }
