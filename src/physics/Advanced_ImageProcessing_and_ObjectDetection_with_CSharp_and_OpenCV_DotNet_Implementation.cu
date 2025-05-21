using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using OpenCvSharp;

namespace ImageProcessingAndObjectDetection
{
    class Program
    {
        static void Main(string[] args)
        {
            string imagePath = "sample_image.jpg";
            string cascadePath = "haarcascade_frontalface_default.xml";

            if (!File.Exists(imagePath) || !File.Exists(cascadePath))
            {
                Console.WriteLine("Image or cascade file not found.");
                return;
            }

            using var srcImage = Cv2.ImRead(imagePath);
            if (srcImage.Empty())
            {
                Console.WriteLine("Failed to load image.");
                return;
            }

            // Convert to grayscale
            using var grayImage = new Mat();
            Cv2.CvtColor(srcImage, grayImage, ColorConversionCodes.BGR2GRAY);

            // Histogram Equalization for better contrast
            Cv2.EqualizeHist(grayImage, grayImage);

            // Load Haar cascade classifier for face detection
            var faceCascade = new CascadeClassifier(cascadePath);

            // Detect faces
            var faces = faceCascade.DetectMultiScale(
                grayImage,
                scaleFactor: 1.1,
                minNeighbors: 5,
                flags: HaarDetectionType.ScaleImage,
                minSize: new Size(30, 30)
            );

            Console.WriteLine($"Detected {faces.Length} face(s). ");

            // Draw rectangles around detected faces
            foreach (var face in faces)
            {
                Cv2.Rectangle(srcImage, face, new Scalar(0, 255, 0), 2);
            }

            // Save the processed image
            string outputPath = "processed_output.jpg";
            Cv2.ImWrite(outputPath, srcImage);
            Console.WriteLine($"Processed image saved to {outputPath}");
        }
    }
}