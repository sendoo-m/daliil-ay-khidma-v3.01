from django import forms
from apps.directory.models import Business, BusinessImage
from apps.directory.models.location import Governorate, City, District
from apps.categories.models import Category


class BusinessCreateForm(forms.ModelForm):
    """فورم إنشاء/تعديل المحل - متعدد الأقسام"""

    # Cascading location fields
    governorate = forms.ModelChoiceField(
        queryset=Governorate.objects.filter(is_active=True).order_by('name_ar'),
        required=True,
        label='المحافظة',
        widget=forms.Select(attrs={
            'class': 'form-select',
            'id': 'id_governorate',
        }),
    )
    city = forms.ModelChoiceField(
        queryset=City.objects.none(),
        required=True,
        label='المدينة',
        widget=forms.Select(attrs={
            'class': 'form-select',
            'id': 'id_city',
        }),
    )

    class Meta:
        model = Business
        fields = [
            # Section 1 - أساسي
            'business_type',
            'name_ar', 'name_en',
            'category',
            'description_ar', 'description_en',
            # Section 2 - الموقع
            'governorate', 'city', 'district',
            'address_ar', 'address_en',
            'latitude', 'longitude', 'location_url',
            # Section 3 - التواصل
            'phone', 'whatsapp', 'email', 'website',
            # Section 4 - السوشيال
            'facebook', 'instagram', 'twitter', 'tiktok',
            # Section 5 - الصور الرئيسية
            'logo', 'cover_image',
            # Section 6 - ساعات العمل
            'working_hours_ar', 'working_hours_en',
        ]
        widgets = {
            # Section 1
            'business_type': forms.Select(attrs={'class': 'form-select', 'id': 'id_business_type'}),
            'name_ar':        forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'اسم المحل بالعربية', 'dir': 'rtl'}),
            'name_en':        forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Business name in English'}),
            'category':       forms.Select(attrs={'class': 'form-select'}),
            'description_ar': forms.Textarea(attrs={'class': 'form-control', 'rows': 4, 'placeholder': 'وصف تفصيلي...', 'dir': 'rtl'}),
            'description_en': forms.Textarea(attrs={'class': 'form-control', 'rows': 4, 'placeholder': 'Detailed description...'}),
            # Section 2
            'district':    forms.Select(attrs={'class': 'form-select', 'id': 'id_district'}),
            'address_ar':  forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'العنوان التفصيلي', 'dir': 'rtl'}),
            'address_en':  forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Detailed address'}),
            'latitude':    forms.HiddenInput(attrs={'id': 'id_latitude'}),
            'longitude':   forms.HiddenInput(attrs={'id': 'id_longitude'}),
            'location_url':forms.URLInput(attrs={'class': 'form-control', 'placeholder': 'https://maps.google.com/...'}),
            # Section 3
            'phone':    forms.TextInput(attrs={'class': 'form-control', 'placeholder': '01xxxxxxxxx'}),
            'whatsapp': forms.TextInput(attrs={'class': 'form-control', 'placeholder': '01xxxxxxxxx'}),
            'email':    forms.EmailInput(attrs={'class': 'form-control', 'placeholder': 'email@example.com'}),
            'website':  forms.URLInput(attrs={'class': 'form-control', 'placeholder': 'https://'}),
            # Section 4
            'facebook':  forms.URLInput(attrs={'class': 'form-control', 'placeholder': 'https://facebook.com/'}),
            'instagram': forms.URLInput(attrs={'class': 'form-control', 'placeholder': 'https://instagram.com/'}),
            'twitter':   forms.URLInput(attrs={'class': 'form-control', 'placeholder': 'https://twitter.com/'}),
            'tiktok':    forms.URLInput(attrs={'class': 'form-control', 'placeholder': 'https://tiktok.com/@'}),
            # Section 6
            'working_hours_ar': forms.Textarea(attrs={'class': 'form-control', 'rows': 3, 'placeholder': 'السبت-الخميس: 9ص-10م', 'dir': 'rtl'}),
            'working_hours_en': forms.Textarea(attrs={'class': 'form-control', 'rows': 3, 'placeholder': 'Sat-Thu: 9AM-10PM'}),
        }

    def __init__(self, *args, business_type=None, user=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.user = user

        # لو نوع المحل محدد مسبقاً (shop/craft) نخفي الـ field ونحدده
        if business_type:
            self.fields['business_type'].initial = business_type
            self.fields['business_type'].widget = forms.HiddenInput()

        # لو مش أدمن نخفي is_active/is_verified/is_featured
        if user and not user.is_staff:
            for f in ['is_active', 'is_verified', 'is_featured']:
                self.fields.pop(f, None)

        # Cascading: لو فيه instance موجودة
        if self.instance.pk and self.instance.district:
            try:
                city = self.instance.district.city
                gov  = city.governorate
                self.fields['governorate'].initial = gov
                self.fields['city'].initial        = city
                self.fields['city'].queryset       = City.objects.filter(
                    governorate=gov, is_active=True
                ).order_by('name_ar')
                self.fields['district'].queryset   = District.objects.filter(
                    city=city, is_active=True
                ).order_by('name_ar')
            except AttributeError:
                pass

        # Cascading: لو POST
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


class BusinessImageForm(forms.ModelForm):
    """فورم صورة واحدة من الـ gallery"""
    class Meta:
        model   = BusinessImage
        # الترتيب قيمة داخلية يحددها النظام تلقائياً حسب موضع الصورة.
        fields  = ['image', 'caption_ar', 'caption_en']
        widgets = {
            'image':      forms.FileInput(attrs={'class': 'form-control', 'accept': 'image/*'}),
            'caption_ar': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'وصف الصورة', 'dir': 'rtl'}),
            'caption_en': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'Image caption'}),
        }


# Formset للـ gallery - حتى 10 صور
from django.forms import inlineformset_factory

BusinessImageFormSet = inlineformset_factory(
    Business,
    BusinessImage,
    form=BusinessImageForm,
    extra=3,        # 3 حقول فاضية للبداية
    max_num=10,     # حد أقصى 10 صور
    can_delete=True,
)
