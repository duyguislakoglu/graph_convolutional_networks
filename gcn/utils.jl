using PyCall
using SparseArrays
const scipy_sparse_find = pyimport("scipy.sparse")["find"]

function load_dataset(dataset, k=0)
    py"""
import numpy as np
import pickle as pkl
import networkx as nx
import scipy.sparse as sp
from scipy.sparse.linalg.eigen.arpack import eigsh
import sys
import os

def parse_index_file(filename):
    index = []
    for line in open(filename):
        index.append(int(line.strip()))
    return index

def sample_mask(idx, l):
    mask = np.zeros(l)
    mask[idx] = 1
    return np.array(mask, dtype=np.bool)

def sparse_to_tuple(sparse_mx):
    #Convert sparse matrix to tuple representation.
    def to_tuple(mx):
        if not sp.isspmatrix_coo(mx):
            mx = mx.tocoo()
        coords = np.vstack((mx.row, mx.col)).transpose()
        values = mx.data
        shape = mx.shape
        return coords, values, shape

    if isinstance(sparse_mx, list):
        for i in range(len(sparse_mx)):
            sparse_mx[i] = to_tuple(sparse_mx[i])
    else:
        sparse_mx = to_tuple(sparse_mx)

    return sparse_mx

def preprocess_features(features):
    # Added for the integers to negative integer powers problem
    features = features.astype(float)
    # Row-normalize feature matrix and convert to tuple representation
    rowsum = np.array(features.sum(1))
    r_inv = np.power(rowsum, -1).flatten()
    r_inv[np.isinf(r_inv)] = 0.
    r_mat_inv = sp.diags(r_inv)
    features = r_mat_inv.dot(features)
    #return sparse_to_tuple(features)
    return features

def normalize_adj(adj):
    # Added for the integers to negative integer powers problem
    adj = adj.astype(float)
    # Symmetrically normalize adjacency matrix.
    adj = sp.coo_matrix(adj)
    rowsum = np.array(adj.sum(1))
    d_inv_sqrt = np.power(rowsum, -0.5).flatten()
    d_inv_sqrt[np.isinf(d_inv_sqrt)] = 0.
    d_mat_inv_sqrt = sp.diags(d_inv_sqrt)
    return adj.dot(d_mat_inv_sqrt).transpose().dot(d_mat_inv_sqrt).tocoo()

def preprocess_adj(adj):
    #Preprocessing of adjacency matrix for simple GCN model and conversion to tuple representation.
    adj_normalized = normalize_adj(adj + sp.eye(adj.shape[0]))
    #return sparse_to_tuple(adj_normalized)
    return adj_normalized

def chebyshev_polynomials(adj, k):
    # Calculate Chebyshev polynomials up to order k. Return a list of sparse matrices (tuple representation).
    print("Calculating Chebyshev polynomials up to order {}...".format(k))

    adj_normalized = normalize_adj(adj)
    laplacian = sp.eye(adj.shape[0]) - adj_normalized
    largest_eigval, _ = eigsh(laplacian, 1, which='LM')
    scaled_laplacian = (2. / largest_eigval[0]) * laplacian - sp.eye(adj.shape[0])

    t_k = list()
    t_k.append(sp.eye(adj.shape[0]))
    t_k.append(scaled_laplacian)

    def chebyshev_recurrence(t_k_minus_one, t_k_minus_two, scaled_lap):
        s_lap = sp.csr_matrix(scaled_lap, copy=True)
        return 2 * s_lap.dot(t_k_minus_one) - t_k_minus_two

    for i in range(2, k+1):
        t_k.append(chebyshev_recurrence(t_k[-1], t_k[-2], scaled_laplacian))
    return t_k

def load_data(dataset_str, k):
    names = ['x', 'y', 'tx', 'ty', 'allx', 'ally', 'graph']
    objects = []
    for i in range(len(names)):
        with open("data/ind.{}.{}".format(dataset_str, names[i]), 'rb') as f:
            if sys.version_info > (3, 0):
                objects.append(pkl.load(f, encoding='latin1'))
            else:
                objects.append(pkl.load(f))
    x, y, tx, ty, allx, ally, graph = tuple(objects)
    test_idx_reorder = parse_index_file("data/ind.{}.test.index".format(dataset_str))
    test_idx_range = np.sort(test_idx_reorder)
    if dataset_str == 'citeseer':
        # Fix citeseer dataset (there are some isolated nodes in the graph)
        # Find isolated nodes, add them as zero-vecs into the right position
        test_idx_range_full = range(min(test_idx_reorder), max(test_idx_reorder)+1)
        tx_extended = sp.lil_matrix((len(test_idx_range_full), x.shape[1]))
        tx_extended[test_idx_range-min(test_idx_range), :] = tx
        tx = tx_extended
        ty_extended = np.zeros((len(test_idx_range_full), y.shape[1]))
        ty_extended[test_idx_range-min(test_idx_range), :] = ty
        ty = ty_extended

    if dataset_str == 'nell':
        def save_sparse_csr(filename, array):
            np.savez(filename, data=array.data, indices=array.indices, indptr=array.indptr, shape=array.shape)
        def load_sparse_csr(filename):
            loader = np.load(filename + '.npz')
            return sp.csr_matrix((loader['data'], loader['indices'], loader['indptr']), shape=loader['shape'])
        test_idx_range_full = range(allx.shape[0], len(graph))
        isolated_node_idx = np.setdiff1d(test_idx_range_full, test_idx_reorder)
        tx_extended = sp.lil_matrix((len(test_idx_range_full), x.shape[1]))
        tx_extended[test_idx_range-allx.shape[0], :] = tx
        tx = tx_extended
        ty_extended = np.zeros((len(test_idx_range_full), y.shape[1]))
        ty_extended[test_idx_range-allx.shape[0], :] = ty
        ty = ty_extended
        features = sp.vstack((allx, tx)).tolil()
        features[test_idx_reorder, :] = features[test_idx_range, :]
        idx_all = np.setdiff1d(range(len(graph)), isolated_node_idx)
        if not os.path.isfile("data/{}.features.npz".format(dataset_str)):
            print("Creating feature vectors for relations - this might take a while...")
            features_extended = sp.hstack((features, sp.lil_matrix((features.shape[0], len(isolated_node_idx)))),
                                          dtype=np.int32).todense()
            features_extended[isolated_node_idx, features.shape[1]:] = np.eye(len(isolated_node_idx))
            features = sp.csr_matrix(features_extended)
            print("Done!")
            save_sparse_csr("data/{}.features".format(dataset_str), features)
        else:
            features = load_sparse_csr("data/{}.features".format(dataset_str))

    else:
        features = sp.vstack((allx, tx)).tolil()
        features[test_idx_reorder, :] = features[test_idx_range, :]

    # Due to GCN issue#76
    G = nx.from_dict_of_lists(graph)
    G = nx.relabel_nodes(G, {i: j for i,j in zip(test_idx_reorder, test_idx_range)})
    adj = nx.adjacency_matrix(G)
    #adj = nx.adjacency_matrix(nx.from_dict_of_lists(graph))

    labels = np.vstack((ally, ty))
    labels[test_idx_reorder, :] = labels[test_idx_range, :]

    idx_test = test_idx_range.tolist()
    idx_train = range(len(y))
    idx_val = range(len(y), len(y)+500)

    features = preprocess_features(features)
    features = np.transpose(features)

    if k != 0:
        adj = chebyshev_polynomials(adj, k)
    else:
        adj = preprocess_adj(adj)

    return adj, features, labels, idx_train, idx_val, test_idx_range
    """

    adj_, features, labels, idx_train, idx_val, idx_test = py"load_data"(dataset, k)
    atype = gpu() >= 0 ? KnetArray{Float32,2} : SparseMatrixCSC{Float32,Int64}

    # Zero-indexing issue
    idx_train = idx_train .+ 1
    idx_val = idx_val .+ 1
    idx_test = idx_test .+ 1

    if k==0
        (I, J, V) = scipy_sparse_find(adj_)
        # Zero-indexing issue
        adj = sparse(I .+ 1, J .+ 1, V)
        convert(atype, adj)
    else
        (I, J, V) = scipy_sparse_find(adj_[1])
        adj1 = sparse(I .+ 1, J .+ 1, V)
#        convert(atype, adj1)
        (I, J, V) = scipy_sparse_find(adj_[2])
        adj2 = sparse(I .+ 1, J .+ 1, V)
#        convert(atype, adj2)
        (I, J, V) = scipy_sparse_find(adj_[3])
        adj3 = sparse(I .+ 1, J .+ 1, V)
#       convert(atype, adj3)
        if k==3
            (I, J, V) = scipy_sparse_find(adj_[4])
            adj4 = sparse(I .+ 1, J .+ 1, V)
    #       convert(atype, adj4)
        end
    end

    (I, J, V) = scipy_sparse_find(features)
    # Zero-indexing issue
    features = sparse(I .+ 1, J .+ 1, V)
#    convert(atype, features)

    if k==0
        return adj, features, labels, idx_train, idx_val, idx_test
    elseif k==2
        return adj1, adj2, adj3, features, labels, idx_train, idx_val, idx_test
    elseif k==3
        return adj1, adj2, adj3, adj4, features, labels, idx_train, idx_val, idx_test
    end
end
