import os
from PIL import Image

dataset_path = "Datasets"

bad_images = 0

for folder in os.listdir(dataset_path):
    folder_path = os.path.join(dataset_path, folder)

    if os.path.isdir(folder_path):
        for file in os.listdir(folder_path):
            file_path = os.path.join(folder_path, file)

            try:
                img = Image.open(file_path)
                img.verify()  # check if image is valid
            except:
                print(f"Removing bad image: {file_path}")
                os.remove(file_path)
                bad_images += 1

print(f"Done! Removed {bad_images} corrupted images.")