(defpackage :fractal-visualization
  (:use :cl))

(in-package :fractal-visualization)

;; Define a function to compute the Mandelbrot set
(defun mandelbrot (x y max-iter)
  (let ((cx x)
        (cy y)
        (zx 0.0)
        (zy 0.0)
        (iteration 0))
    (loop while (< (+ (* zx zx) (* zy zy)) 4.0)
          do (progn
               (setf (zx) (+ (- (* zx zx) (* zy zy)) cx))
               (setf (zy) (+ (* 2 zx zy) cy))
               (incf iteration)
               (when (>= iteration max-iter)
                 (return iteration))))
    iteration))

;; Map iteration count to color
(defun color-for-iteration (iteration max-iter)
  (let ((ratio (/ iteration max-iter)))
    ;; Generate a color gradient from blue to red
    (format nil "#~2,'0X~2,'0X~2,'0X"
            (* 255 ratio)  ; Red component
            (* 255 (- 1 ratio))  ; Green component
            (* 128 ratio))))  ; Blue component

;; Generate a grid of points for visualization
(defun generate-grid (width height x-min x-max y-min y-max)
  (let ((x-step (/ (- x-max x-min) width))
        (y-step (/ (- y-max y-min) height)))
        points '())
    (loop for i from 0 to (- width 1)
          do (loop for j from 0 to (- height 1)
                   do (let ((x (+ x-min (* i x-step)))
                            (y (+ y-min (* j y-step))))
                        (push (cons x y) points))))
    points))

;; Main function to create the visualization data
(defun create-fractal-data (width height x-min x-max y-min y-max max-iter)
  (let ((grid (generate-grid width height x-min x-max y-min y-max))
        (result '()))
    (dolist (point grid)
      (let* ((x (car point))
             (y (cdr point))
             (iter (mandelbrot x y max-iter))
             (color (color-for-iteration iter max-iter)))
        (push (list :x x :y y :color color :iteration iter) result)))
    result))

;; Function to generate SVG visualization
(defun generate-svg (data width height &key (title "Fractal Mandelbrot Set"))
  (with-open-file (stream "fractal.svg" :direction :output :if-exists :supersede)
    (format stream "<svg xmlns='http://www.w3.org/2000/svg' width='~a' height='~a'>~%" width height)
    (format stream "<title>~a</title>~%" title)
    (dolist (point data)
      (let ((x (getf point :x))
            (y (getf point :y))
            (color (getf point :color)))
            ;; Map x, y to pixel coordinates
            (let ((px (/ (* (+ x (- 2.0)) 1.0) 3.0) *width*)
                  (py (/ (* (+ y (- 1.5)) 1.5) 3.0) *height*)))
              (format stream "<rect x='~a' y='~a' width='1' height='1' fill='~a' />~%" (round (* px 1.0)) (round (* py 1.0)) color))))
    (format stream "</svg>"))))

;; Entry point to generate and save the fractal visualization
(defun main ()
  (let ((width 800)
        (height 600)
        (x-min -2.0)
        (x-max 1.0)
        (y-min -1.5)
        (y-max 1.5)
        (max-iter 100))
    (let ((data (create-fractal-data width height x-min x-max y-min y-max max-iter)))
      (generate-svg data width height))))

(main)
