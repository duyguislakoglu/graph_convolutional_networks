Thomas N. Kipf, Max Welling. 2017, [<span class="underline">Semi-supervised Classification With Graph Convolutional Networks</span>](https://arxiv.org/pdf/1609.02907.pdf), In *International Conference on Learning Representations (ICLR)*

## Requirements

  * KNET

## Usage

```julia train.jl```

## Parameters

        ("--dataset"; arg_type=AbstractString; default="cora"; help="The name of the dataset.")
        ("--model"; arg_type=AbstractString; default="gcn"; help="The name of the model: gcn, gcn_cheby or dense")
        ("--epochs"; arg_type=Int; default=200; help="Number of epochs to train.")
        ("--lr"; arg_type=Float64; default=0.01; help="Initial learning rate.")
        ("--weight_decay"; arg_type=Float64; default=5e-4; help="Weight for L2 loss on embedding matrix.")
        ("--hidden"; arg_type=Int; default=16; help="Number of units in hidden layer.")
        ("--pdrop"; arg_type=Float64; default=0.5; help="Dropout rate (1 - keep probability).")
        ("--window_size"; arg_type=Int; default=10; help="Tolerance for early stopping (# of epochs).'")
        ("--load_file"; default=""; help="The path to load a saved model.")
        ("--num_of_runs"; arg_type=Int; default=1; help="The number of randomly initialized runs.")
        ("--save_epoch_num"; arg_type=Int; default=250; help="The number of epochs to save the model.")
        ("--chebyshev_max_degree"; arg_type=Int; default=0; help="Maximum Chebyshev polynomial degree.")

**Original Code:**

[<span class="underline">https://github.com/tkipf/gcn</span>](https://github.com/tkipf/gcn)

[<span class="underline">https://github.com/tkipf/pygcn</span>](https://github.com/tkipf/pygcn)


**Datasets:**![](/media/image1.png)

**1-** [<span class="underline">Citeseer</span>](https://github.com/kimiyoung/planetoid/tree/master/data)

**2-** [<span class="underline">Cora</span>](https://github.com/kimiyoung/planetoid/tree/master/data)

**3-** [<span class="underline">Pubmed</span>](https://github.com/kimiyoung/planetoid/tree/master/data)

**4-** [<span class="underline">NELL</span>](http://www.cs.cmu.edu/~zhiliny/data/nell_data.tar.gz)

**Baselines**

**1- Semi-Supervised Node Classification**

1.  > Label propagation (LP) (Zhu et al., 2003)

2.  > Semi-supervised embedding (SemiEmb) (Weston et al., 2012)

3.  > Manifold regularization (ManiReg) (Belkin et al., 2006)

4.  > Skip-gram based graph embeddings (DeepWalk) (Perozzi et al., 2014)

5.  > Planetoid (Yang et al., 2016)

6.  > Iterative classification algorithm (ICA) (Lu & Getoor, 2003)
