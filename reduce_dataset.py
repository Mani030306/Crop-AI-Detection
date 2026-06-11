import os
import random

dataset_path = "Datasets"  # change if needed
TARGET = 500

for folder in os.listdir(dataset_path):
    folder_path = os.path.join(dataset_path, folder)

    if os.path.isdir(folder_path):
        images = os.listdir(folder_path)

        if len(images) > TARGET:
            print(f"Reducing {folder} from {len(images)} to {TARGET}")

            random.shuffle(images)
            to_delete = images[TARGET:]

            for img in to_delete:
                img_path = os.path.join(folder_path, img)
                os.remove(img_path)

print("Done!")
