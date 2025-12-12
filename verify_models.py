"""
Model Verification Script
Run this after training to verify your .pth files are valid
"""

import torch
import os
from pathlib import Path

def verify_model_file(filepath, model_name):
    """Verify a .pth model file is valid and loadable"""
    print(f"\n{'='*60}")
    print(f"Verifying: {model_name}")
    print(f"{'='*60}")
    
    # Check file exists
    if not os.path.exists(filepath):
        print(f"❌ File not found: {filepath}")
        return False
    
    # Check file size
    file_size_mb = os.path.getsize(filepath) / (1024 * 1024)
    print(f"📁 File: {filepath}")
    print(f"💾 Size: {file_size_mb:.2f} MB")
    
    # Verify it's a valid torch file
    try:
        checkpoint = torch.load(filepath, map_location='cpu')
        print(f"✅ File is loadable")
        
        # Check if it's a state dict
        if isinstance(checkpoint, dict):
            num_layers = len(checkpoint)
            print(f"📊 Number of layers: {num_layers}")
            
            # Show first few layer names
            layer_names = list(checkpoint.keys())[:5]
            print(f"🔍 First 5 layers:")
            for name in layer_names:
                print(f"   - {name}")
            
            # Check for expected size ranges
            if model_name == "VGG16" and file_size_mb > 400:
                print(f"✅ File size appropriate for VGG16")
            elif model_name == "ResNet18" and 40 < file_size_mb < 60:
                print(f"✅ File size appropriate for ResNet18")
            elif model_name == "MobileNetV2" and 10 < file_size_mb < 20:
                print(f"✅ File size appropriate for MobileNetV2")
            elif model_name == "AlexNet" and 200 < file_size_mb < 250:
                print(f"✅ File size appropriate for AlexNet")
            elif model_name == "ViT" and 300 < file_size_mb < 400:
                print(f"✅ File size appropriate for ViT")
            else:
                print(f"⚠️  File size unusual for {model_name}")
            
            return True
        else:
            print(f"⚠️  Checkpoint is not a state dictionary")
            return False
            
    except Exception as e:
        print(f"❌ Error loading file: {str(e)}")
        return False

def main():
    """Check all model files"""
    print("\n" + "🔍 SiteLenz Model Verification Tool" + "\n")
    
    # Define expected model files
    models_to_check = {
        'VGG16': 'vgg16/vgg16_weights.pth',
        'ResNet18': 'resnet18/resnet18_weights.pth',
        'MobileNetV2': 'mobilenet/mobilenet_weights.pth',
        'AlexNet': 'alexnet/alexnet_weights.pth',
        'ViT': 'vit/vit_weights.pth'
    }
    
    results = {}
    
    # Check each model
    for model_name, filepath in models_to_check.items():
        results[model_name] = verify_model_file(filepath, model_name)
    
    # Summary
    print(f"\n{'='*60}")
    print("📋 VERIFICATION SUMMARY")
    print(f"{'='*60}")
    
    valid_count = sum(results.values())
    total_count = len(results)
    
    for model_name, is_valid in results.items():
        status = "✅ Valid" if is_valid else "❌ Missing/Invalid"
        print(f"{model_name:15s} : {status}")
    
    print(f"\n{valid_count}/{total_count} models verified successfully")
    
    if valid_count == total_count:
        print("\n🎉 All models are ready to use!")
        print("You can now use load_trained_models.ipynb for inference")
    elif valid_count > 0:
        print(f"\n⚠️  {total_count - valid_count} model(s) missing or invalid")
        print("Train the missing models or check file paths")
    else:
        print("\n❌ No valid models found")
        print("Please train your models first")
    
    print(f"\n{'='*60}\n")

if __name__ == "__main__":
    main()
