using Knet: dropout, nll, Data
using Statistics
include("layers.jl")

# Architecture
struct GCN
    layer1::GCLayer
    layer2::GCLayer
    pdrop
end

# Constructor
GCN(nfeat::Int, nhid::Int, nclass::Int, adj, pdrop=0) = GCN(GCLayer(nfeat, nhid, adj), GCLayer(nhid, nclass, adj, identity), pdrop)

# Forward
function (g::GCN)(x)
    x = g.layer1(x)
    x = dropout(x, g.pdrop)
    g.layer2(x)
end

# Loss
# (g::GCN)(x,y) is defined in train.jl
(g::GCN)(d::Data) = mean(g(x,y) for (x,y) in d)

# Architecture
struct MLP
    layer1::DenseLayer
    layer2::DenseLayer
end

# Constructor
MLP(nfeat::Int, nhid::Int, nclass::Int, pdrop=0) = MLP(DenseLayer(nfeat, nhid, relu, pdrop), DenseLayer(nhid, nclass, identity, pdrop))

# Forward
function (m::MLP)(x)
    x = m.layer1(x)
    m.layer2(x)
end

# Loss
# (g::GCN)(x,y) is defined in train.jl
(m::MLP)(d::Data) = mean(m(x,y) for (x,y) in d)
