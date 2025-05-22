Red [
    Needs: 'Math
]
Neural-Layer: context [
    field weights
    field biases
    field input
    field output
    field activation-fn
    field delta
    field prev-w-grad
    field prev-b-grad
    field learning-rate
    field momentum
    field has-momentum?
    ; Constructor for a neural network layer
    make: func [w [series!][vector!][block!]] [ 
        either any w [
            either vector? w [
                either length? w [][
                    ; Already a properly initialized weight vector
                ][
                    to series! w
                ]
            ][
                to series! w
            ]
        ][
            [] ; fallback
        ]
    ]
    initialize: func [layer [block!][series!][series!][series!][series!][series!][series!][series!][series!][series!][series!][series!]] [
        layer: copy/deep layer
        layer/weights: copy/deep layer/weights
        layer/biases: copy/deep layer/biases
        layer/input: copy/deep layer/input
        layer/output: copy/deep layer/output
        layer/delta: copy/deep layer/delta
        layer/prev-w-grad: copy/deep layer/prev-w-grad
        layer/prev-b-grad: copy/deep layer/prev-b-grad
        layer/activation-fn: either/all [layer/activation-fn] [
            quote [identity]
        ][
            quote [identity]
        ]
        layer/learning-rate: either/all [layer/learning-rate] [0.01]
        layer/momentum: either/all [layer/momentum] [0.9]
        layer/has-momentum?: false
        layer
    ]
    create: func [size [integer!] [activation-fn [block!]] [learning-rate [decimal!]][momentum [decimal!]]] [
        layer: make [
            weights: copy []
            biases: copy []
            input: to series! []
            output: to series! []
            delta: to series! []
            prev-w-grad: copy []
            prev-b-grad: copy []
            activation-fn: activation-fn
            learning-rate: learning-rate
            momentum: momentum
            has-momentum?: false
        ]
        loop i 1 size [
            append layer/weights 0.0
            append layer/biases 0.0
            append layer/prev-w-grad 0.0
            append layer/prev-b-grad 0.0
        ]
        layer
    ]
    forward: func [layer [block!]] [
        layer/input: copy/deep layer/input
        unless [length? layer/weights = length? layer/input] [
            repeat i 1 length? layer/weights [
                length? layer/input = length? layer/weights [
                    break
                ]
                append layer/input 0.0
            ]
        ]
        layer/output: copy/deep layer/output
        foreach i range 0 length? layer/weights [
            sum: 0.0
            for j 0 length? layer/input [
                sum: sum + (layer/weights/ i) * (layer/input / j)
            ]
            append layer/output sum
        ]
        layer/output: map layer/output [layer/activation-fn /copy ?]
        layer/output
    ]
    compute-delta: func [layer [block!]] [
        delta: copy/deep layer/delta
        for i 0 length? layer/output [
            delta[i] := 0.0
        ]
        for i 0 length? layer/output [
            delta[i] := (layer/output / i) - (layer/input / i)
        ]
        delta
    ]
    backward: func [layer [block!]] [
        inputs: copy/deep layer/input
        output: copy/deep layer/output
        delta: copy/deep layer/delta
        for i 0 length? layer/weights [
            for j 0 length? inputs [
                weight-update: (layer/learning-rate * delta / i) * inputs / j
                if layer/has-momentum? [
                    layer/prev-w-grad / i: (layer/momentum * layer/prev-w-grad / i) + weight-update
                    layer/weights / i: (layer/weights / i) - layer/prev-w-grad / i
                ] [
                    layer/weights / i: (layer/weights / i) - weight-update
                ]
            ]
            bias-update: layer/learning-rate * delta / i
            if layer/has-momentum? [
                layer/prev-b-grad / i: (layer/momentum * layer/prev-b-grad / i) + bias-update
                layer/biases / i: (layer/biases / i) - layer/prev-b-grad / i
            ] [
                layer/biases / i: (layer/biases / i) - bias-update
            ]
        ]
        layer
    ]
    update-weights: func [layer [block!]] [
        layer
    ]
    set-momentum?: func [layer [block!][boolean!]] [
        layer/has-momentum?: layer
        layer
    ]
    train: func [layer [block!][series!][series!][series!]] [
        temp: copy/deep layer
        forward temp data
        compute-delta temp
        backward temp
        temp
    ]
]