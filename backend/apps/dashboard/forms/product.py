"""
Product Form
"""

from django import forms
from apps.products.models import Product
from apps.directory.models import Business


class ProductForm(forms.ModelForm):
    """Product Creation/Update Form"""
    
    def __init__(self, *args, **kwargs):
        self.user = kwargs.pop('user', None)
        super().__init__(*args, **kwargs)
        
        # Limit business choices to user's businesses
        if self.user:
            self.fields['business'].queryset = Business.objects.filter(owner=self.user)
    
    class Meta:
        model = Product
        fields = [
            'business',
            'product_type',
            'name_en', 'name_ar',
            'description_en', 'description_ar',
            'price', 'old_price',
            'is_available', 'is_featured',
            'stock_quantity',
        ]
        
        widgets = {
            'business': forms.Select(attrs={
                'class': 'form-select'
            }),
            'product_type': forms.Select(attrs={
                'class': 'form-select'
            }),
            'name_en': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Product/Service name in English'
            }),
            'name_ar': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'اسم المنتج/الخدمة',
                'dir': 'rtl'
            }),
            'description_en': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 4,
                'placeholder': 'Product description'
            }),
            'description_ar': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 4,
                'placeholder': 'وصف المنتج',
                'dir': 'rtl'
            }),
            'price': forms.NumberInput(attrs={
                'class': 'form-control',
                'step': '0.01',
                'min': '0'
            }),
            'old_price': forms.NumberInput(attrs={
                'class': 'form-control',
                'step': '0.01',
                'min': '0'
            }),
            'stock_quantity': forms.NumberInput(attrs={
                'class': 'form-control',
                'min': '0'
            }),
            'is_available': forms.CheckboxInput(attrs={
                'class': 'form-check-input'
            }),
            'is_featured': forms.CheckboxInput(attrs={
                'class': 'form-check-input'
            }),
        }
        
        labels = {
            'business': 'المحل',
            'product_type': 'النوع',
            'name_en': 'Product Name (English)',
            'name_ar': 'اسم المنتج',
            'description_en': 'Description (English)',
            'description_ar': 'الوصف',
            'price': 'السعر',
            'old_price': 'السعر القديم',
            'stock_quantity': 'الكمية',
            'is_available': 'متوفر',
            'is_featured': 'مميز',
        }
