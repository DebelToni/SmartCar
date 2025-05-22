class DenseLayer(
    private val inputSize: Int,
    private val outputSize: Int,
    private val activation: ActivationFunction = ReLU(),
    private val weightInitializer: WeightInitializer = XavierInitializer(),
    private val biasInitializer: BiasInitializer = ZeroBiasInitializer()
) {
    private val weights: Array<DoubleArray> = Array(inputSize) { DoubleArray(outputSize) }
    private val biases: DoubleArray = DoubleArray(outputSize)
    private var inputCache: DoubleArray? = null
    private var outputCache: DoubleArray? = null
    private var weightGradients: Array<DoubleArray> = Array(inputSize) { DoubleArray(outputSize) }
    private var biasGradients: DoubleArray = DoubleArray(outputSize)
    private var learningRate: Double = 0.01
    private var regularizationFactor: Double = 0.0

    init {
        initializeWeights()
        initializeBiases()
    }

    private fun initializeWeights() {
        weightInitializer.initialize(weights)
    }

    private fun initializeBiases() {
        biasInitializer.initialize(biases)
    }

    fun forward(input: DoubleArray): DoubleArray {
        require(input.size == inputSize) { "Input size mismatch" }
        inputCache = input.copyOf()
        val output = DoubleArray(outputSize)
        for (j in 0 until outputSize) {
            var sum = biases[j]
            for (i in 0 until inputSize) {
                sum += input[i] * weights[i][j]
            }
            output[j] = activation.activate(sum)
        }
        outputCache = output
        return output
    }

    fun backward(
        upstreamGradient: DoubleArray,
        optimizer: Optimizer
    ): DoubleArray {
        val input = inputCache ?: throw IllegalStateException("Must call forward before backward")
        val delta = DoubleArray(outputSize)
        for (j in 0 until outputSize) {
            delta[j] = upstreamGradient[j] * activation.derivative(outputCache!![j])
        }
        for (i in 0 until inputSize) {
            for (j in 0 until outputSize) {
                weightGradients[i][j] = delta[j] * input[i] + regularizationFactor * weights[i][j]
            }
        }
        for (j in 0 until outputSize) {
            biasGradients[j] = delta[j]
        }
        val inputGradient = DoubleArray(inputSize)
        for (i in 0 until inputSize) {
            var sumGrad = 0.0
            for (j in 0 until outputSize) {
                sumGrad += weights[i][j] * delta[j]
            }
            inputGradient[i] = sumGrad
        }
        updateParameters(optimizer)
        return inputGradient
    }

    private fun updateParameters(optimizer: Optimizer) {
        for (i in 0 until inputSize) {
            for (j in 0 until outputSize) {
                weights[i][j] = optimizer.update(weights[i][j], weightGradients[i][j])
            }
        }
        for (j in 0 until outputSize) {
            biases[j] = optimizer.update(biases[j], biasGradients[j])
        }
    }

    fun setLearningRate(rate: Double) {
        this.learningRate = rate
    }

    fun setRegularization(factor: Double) {
        this.regularizationFactor = factor
    }

    interface ActivationFunction {
        fun activate(x: Double): Double
        fun derivative(x: Double): Double
    }

    class ReLU : ActivationFunction {
        override fun activate(x: Double): Double = maxOf(0.0, x)
        override fun derivative(x: Double): Double = if (x > 0) 1.0 else 0.0
    }

    interface WeightInitializer {
        fun initialize(weights: Array<DoubleArray>)
    }

    class XavierInitializer : WeightInitializer {
        override fun initialize(weights: Array<DoubleArray>) {
            val limit = sqrt(6.0 / (weights.size + weights[0].size))
            for (i in weights.indices) {
                for (j in weights[i].indices) {
                    weights[i][j] = (Math.random() * 2 * limit) - limit
                }
            }
        }
    }

    interface BiasInitializer {
        fun initialize(biases: DoubleArray)
    }

    class ZeroBiasInitializer : BiasInitializer {
        override fun initialize(biases: DoubleArray) {
            for (i in biases.indices) {
                biases[i] = 0.0
            }
        }
    }

    interface Optimizer {
        fun update(param: Double, gradient: Double): Double
    }

    class SGD(private val momentum: Double = 0.0) : Optimizer {
        private val velocity: MutableMap<Double, Double> = mutableMapOf()

        override fun update(param: Double, gradient: Double): Double {
            val v = velocity.getOrDefault(param, 0.0)
            val newV = momentum * v - learningRate * gradient
            velocity[param] = newV
            return param + newV
        }
    }

    data class LayerOutput(val output: DoubleArray, val input: DoubleArray)

    fun copy(): DenseLayer {
        val newLayer = DenseLayer(inputSize, outputSize, activation, weightInitializer, biasInitializer)
        for (i in weights.indices) {
            for (j in weights[i].indices) {
                newLayer.weights[i][j] = this.weights[i][j]
            }
        }
        for (j in biases.indices) {
            newLayer.biases[j] = this.biases[j]
        }
        return newLayer
    }
}