"""
Account Forms
=============
نماذج التسجيل والدخول والملف الشخصي
"""

from django import forms
from django.contrib.auth.forms import (
    UserCreationForm,
    AuthenticationForm,
    PasswordChangeForm as BasePasswordChangeForm,
    PasswordResetForm as BasePasswordResetForm,
    SetPasswordForm as BaseSetPasswordForm
)
from django.core.exceptions import ValidationError

from .models import User


class RegistrationForm(UserCreationForm):
    """نموذج تسجيل مستخدم جديد"""
    
    email = forms.EmailField(
        required=True,
        widget=forms.EmailInput(attrs={
            'class': 'form-control',
            'placeholder': 'البريد الإلكتروني',
            'dir': 'ltr'
        })
    )
    
    phone = forms.CharField(
        required=True,
        widget=forms.TextInput(attrs={
            'class': 'form-control',
            'placeholder': '01234567890',
            'dir': 'ltr'
        })
    )
    
    class Meta:
        model = User
        fields = ['username', 'email', 'phone', 'password1', 'password2']
        widgets = {
            'username': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'اسم المستخدم',
                'dir': 'ltr'
            }),
        }
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['password1'].widget.attrs.update({
            'class': 'form-control',
            'placeholder': 'كلمة المرور',
            'dir': 'ltr'
        })
        self.fields['password2'].widget.attrs.update({
            'class': 'form-control',
            'placeholder': 'تأكيد كلمة المرور',
            'dir': 'ltr'
        })
        
        # Custom labels
        self.fields['username'].label = 'اسم المستخدم'
        self.fields['email'].label = 'البريد الإلكتروني'
        self.fields['phone'].label = 'رقم الهاتف'
        self.fields['password1'].label = 'كلمة المرور'
        self.fields['password2'].label = 'تأكيد كلمة المرور'
    
    def clean_email(self):
        """التحقق من عدم تكرار البريد"""
        email = self.cleaned_data.get('email')
        if User.objects.filter(email=email).exists():
            raise ValidationError('هذا البريد مستخدم بالفعل')
        return email
    
    def clean_phone(self):
        """التحقق من عدم تكرار الهاتف"""
        phone = self.cleaned_data.get('phone')
        if User.objects.filter(phone=phone).exists():
            raise ValidationError('هذا الرقم مستخدم بالفعل')
        return phone


class LoginForm(AuthenticationForm):
    """نموذج تسجيل الدخول"""
    
    username = forms.CharField(
        widget=forms.TextInput(attrs={
            'class': 'form-control',
            'placeholder': 'اسم المستخدم أو البريد الإلكتروني',
            'dir': 'ltr'
        })
    )
    
    password = forms.CharField(
        widget=forms.PasswordInput(attrs={
            'class': 'form-control',
            'placeholder': 'كلمة المرور',
            'dir': 'ltr'
        })
    )
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['username'].label = 'اسم المستخدم'
        self.fields['password'].label = 'كلمة المرور'


class ProfileUpdateForm(forms.ModelForm):
    """نموذج تحديث الملف الشخصي"""
    
    class Meta:
        model = User
        fields = [
            'first_name',
            'last_name',
            'email',
            'phone',
            'profile_picture',
            'bio',
            'city',
        ]
        widgets = {
            'first_name': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'الاسم الأول'
            }),
            'last_name': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'الاسم الأخير'
            }),
            'email': forms.EmailInput(attrs={
                'class': 'form-control',
                'placeholder': 'email@example.com',
                'dir': 'ltr'
            }),
            'phone': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': '01234567890',
                'dir': 'ltr'
            }),
            'profile_picture': forms.FileInput(attrs={
                'class': 'form-control',
                'accept': 'image/*'
            }),
            'bio': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 4,
                'placeholder': 'نبذة عنك...'
            }),
            'city': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'المدينة'
            }),
        }
        labels = {
            'first_name': 'الاسم الأول',
            'last_name': 'الاسم الأخير',
            'email': 'البريد الإلكتروني',
            'phone': 'رقم الهاتف',
            'profile_picture': 'الصورة الشخصية',
            'bio': 'نبذة عنك',
            'city': 'المدينة',
        }
    
    def clean_email(self):
        """التحقق من عدم تكرار البريد"""
        email = self.cleaned_data.get('email')
        if User.objects.filter(email=email).exclude(pk=self.instance.pk).exists():
            raise ValidationError('هذا البريد مستخدم بالفعل')
        return email
    
    def clean_phone(self):
        """التحقق من عدم تكرار الهاتف"""
        phone = self.cleaned_data.get('phone')
        if User.objects.filter(phone=phone).exclude(pk=self.instance.pk).exists():
            raise ValidationError('هذا الرقم مستخدم بالفعل')
        return phone


class PasswordChangeForm(BasePasswordChangeForm):
    """نموذج تغيير كلمة المرور"""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
        self.fields['old_password'].widget.attrs.update({
            'class': 'form-control',
            'placeholder': 'كلمة المرور الحالية',
            'dir': 'ltr'
        })
        self.fields['new_password1'].widget.attrs.update({
            'class': 'form-control',
            'placeholder': 'كلمة المرور الجديدة',
            'dir': 'ltr'
        })
        self.fields['new_password2'].widget.attrs.update({
            'class': 'form-control',
            'placeholder': 'تأكيد كلمة المرور',
            'dir': 'ltr'
        })
        
        self.fields['old_password'].label = 'كلمة المرور الحالية'
        self.fields['new_password1'].label = 'كلمة المرور الجديدة'
        self.fields['new_password2'].label = 'تأكيد كلمة المرور'


class PasswordResetForm(BasePasswordResetForm):
    """نموذج استرجاع كلمة المرور"""
    
    email = forms.EmailField(
        widget=forms.EmailInput(attrs={
            'class': 'form-control',
            'placeholder': 'البريد الإلكتروني',
            'dir': 'ltr'
        })
    )
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['email'].label = 'البريد الإلكتروني'


class SetPasswordForm(BaseSetPasswordForm):
    """نموذج تعيين كلمة مرور جديدة"""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
        self.fields['new_password1'].widget.attrs.update({
            'class': 'form-control',
            'placeholder': 'كلمة المرور الجديدة',
            'dir': 'ltr'
        })
        self.fields['new_password2'].widget.attrs.update({
            'class': 'form-control',
            'placeholder': 'تأكيد كلمة المرور',
            'dir': 'ltr'
        })
        
        self.fields['new_password1'].label = 'كلمة المرور الجديدة'
        self.fields['new_password2'].label = 'تأكيد كلمة المرور'
