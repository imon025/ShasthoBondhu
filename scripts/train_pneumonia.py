import tensorflow as tf
from tensorflow.keras import layers, models, optimizers
import os

# 1. Dataset Configuration
DATASET_PATH = 'Radiography'
IMG_SIZE = (64, 64) # Fast-Lite Resolution
BATCH_SIZE = 32
ASSETS_PATH = '../assets/models'

# 2. Data Preparation
print("Loading dataset...")
train_ds = tf.keras.preprocessing.image_dataset_from_directory(
    os.path.join(DATASET_PATH, 'train'),
    image_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    label_mode='binary'
).take(50) # Take 50 batches (~1600 images) for 'Fast-Lite' training

val_ds = tf.keras.preprocessing.image_dataset_from_directory(
    os.path.join(DATASET_PATH, 'val'),
    image_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    label_mode='binary'
)

# 3. Fast-Lite CNN Architecture
model = models.Sequential([
    layers.Rescaling(1./255, input_shape=(64, 64, 3)),
    layers.Conv2D(16, 3, padding='same', activation='relu'),
    layers.MaxPooling2D(),
    layers.Conv2D(32, 3, padding='same', activation='relu'),
    layers.MaxPooling2D(),
    layers.Conv2D(64, 3, padding='same', activation='relu'),
    layers.MaxPooling2D(),
    layers.Flatten(),
    layers.Dense(128, activation='relu'),
    layers.Dense(1, activation='sigmoid')
])

model.compile(
    optimizer='adam',
    loss='binary_crossentropy',
    metrics=['accuracy']
)

# 4. Training (Fast-Lite: 5 epochs)
print("Starting Fast-Lite training...")
model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=5
)

# 5. Export to TFLite
print("Exporting to TFLite...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

if not os.path.exists(ASSETS_PATH):
    os.makedirs(ASSETS_PATH)

output_file = os.path.join(ASSETS_PATH, 'pneumonia_model.tflite')
with open(output_file, 'wb') as f:
    f.write(tflite_model)

print(f"Done! REAL model generated at {output_file}")
