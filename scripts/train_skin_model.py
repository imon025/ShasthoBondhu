import os
import tensorflow as tf
from tensorflow.keras import layers, models, applications

def main():
    dataset_dir = '/home/imonfarazi/9 Semester/MobileAppDevelop/skinDataset_extracted/SkinDisease/SkinDisease/train'
    output_model_path = '/home/imonfarazi/9 Semester/MobileAppDevelop/shasthobondhu/assets/models/skin_model.tflite'
    output_labels_path = '/home/imonfarazi/9 Semester/MobileAppDevelop/shasthobondhu/assets/models/skin_labels.txt'

    IMG_SIZE = (224, 224)
    BATCH_SIZE = 32
    EPOCHS = 10 # Increased for better accuracy

    print("Loading dataset...")
    # Load dataset with augmentation for better generalization
    train_ds = tf.keras.utils.image_dataset_from_directory(
        dataset_dir,
        validation_split=0.2,
        subset="training",
        seed=123,
        image_size=IMG_SIZE,
        batch_size=BATCH_SIZE
    )
    
    val_ds = tf.keras.utils.image_dataset_from_directory(
        dataset_dir,
        validation_split=0.2,
        subset="validation",
        seed=123,
        image_size=IMG_SIZE,
        batch_size=BATCH_SIZE
    )

    class_names = train_ds.class_names
    num_classes = len(class_names)
    print(f"Found {num_classes} classes: {class_names}")

    # Save labels
    os.makedirs(os.path.dirname(output_labels_path), exist_ok=True)
    with open(output_labels_path, 'w') as f:
        f.write('\n'.join(class_names))

    # Data augmentation layers
    data_augmentation = tf.keras.Sequential([
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.2),
        layers.RandomZoom(0.2),
    ])

    # Base model (EfficientNetB0 is small but very accurate)
    base_model = applications.EfficientNetB0(
        input_shape=IMG_SIZE + (3,),
        include_top=False,
        weights='imagenet'
    )
    
    # Freeze the base model for initial training
    base_model.trainable = False

    # Model architecture
    inputs = tf.keras.Input(shape=IMG_SIZE + (3,))
    # EfficientNetB0 does not need manual rescaling as it is built into the model
    x = data_augmentation(inputs)
    x = base_model(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.BatchNormalization()(x)
    x = layers.Dropout(0.3)(x)
    outputs = layers.Dense(num_classes, activation='softmax')(x)
    model = models.Model(inputs, outputs)

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss=tf.keras.losses.SparseCategoricalCrossentropy(),
        metrics=['accuracy']
    )

    # Train the top layer
    print(f"Training top layers for {EPOCHS} epochs...")
    model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS)

    # Fine-tuning: Unfreeze the top layers of the base model
    print("Fine-tuning the model...")
    base_model.trainable = True
    # Freeze the bottom layers, unfreeze the top 20 layers
    for layer in base_model.layers[:-20]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-4),
        loss=tf.keras.losses.SparseCategoricalCrossentropy(),
        metrics=['accuracy']
    )

    # Train for a few more epochs to fine-tune
    model.fit(train_ds, validation_data=val_ds, epochs=5)

    print("Converting to TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    # Enable optimizations for mobile
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    with open(output_model_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"High-accuracy model saved to {output_model_path}")

if __name__ == '__main__':
    main()
