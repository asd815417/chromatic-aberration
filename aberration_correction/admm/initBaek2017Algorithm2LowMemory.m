function [out, weights] = initBaek2017Algorithm2LowMemory(varargin)
% INITBAEK2017ALGORITHM2LOWMEMORY  Allocate memory for 'baek2017Algorithm2LowMemory()'
%
% ## Syntax
% [out, weights] = initBaek2017Algorithm2LowMemory(...
%   J_2D, align, dispersion_matrix, sensitivity,...
%   weights, options...
% )
% out = initBaek2017Algorithm2LowMemory(...
%   J_2D, align, dispersion_matrix, sensitivity,...
%   enabled_weights, options...
% )
% [out, weights] = initBaek2017Algorithm2LowMemory(out, weights, options)
% out = initBaek2017Algorithm2LowMemory(out)
%
% ## Description
% [out, weights] = initBaek2017Algorithm2LowMemory(...
%   J_2D, align, dispersion_matrix, sensitivity,...
%   weights, options...
% )
%   Returns a structure containing arrays to be used by
%   'baek2017Algorithm2LowMemory()', as well as normalized regularization
%   weights for 'baek2017Algorithm2LowMemory()'.
%
% out = initBaek2017Algorithm2LowMemory(...
%   J_2D, align, dispersion_matrix, sensitivity,...
%   enabled_weights, options...
% )
%   Omits computations relating to regulariation weights, to be done during
%   a subsequent call using the third call syntax.
%
% [out, weights] = initBaek2017Algorithm2LowMemory(out, weights, options)
%   Adjusts the `out` structure to account for the new value of `weights`.
%   Does not re-initialize the estimated image, `out.I`.
%
% out = initBaek2017Algorithm2LowMemory(out)
%   Re-initializes only the estimated image, `out.I`.
%
% ## Input Arguments
%
% J_2D -- Input RAW image
%   A 2D array containing the raw colour-filter pattern data of an image.
%   The input image is referred to as `J` below, not `J_2D`, because it is
%   usually used in column vector form.
%
% align -- Bayer pattern description
%   A four-character character vector, specifying the Bayer tile pattern of
%   the input image `J`. For example, 'gbrg'. `align` has the same form
%   as the `sensorAlignment` input argument of `demosaic()`.
%
% dispersion_matrix -- Model of dispersion
%   `dispersion_matrix` can be empty (`[]`), if there is no model of
%   dispersion. Otherwise, `dispersion_matrix` must be a matrix for warping
%   `I`, the latent image, to the space of `J`, which is affected by
%   dispersion, and simultaneously converting `I` to the colour space of `J`.
%
% sensitivity -- Spectral band conversion matrix
%   A 2D array, where `sensitivity(i, j)` is the sensitivity of the i-th
%   colour channel of the input image `J` to the j-th colour channel or
%   spectral band of `I`. `sensitivity` is a matrix mapping colours in `I`
%   to colours in `J`.
%
% weights -- Regularization weights
%   `weights(1)` is the 'alpha' weight on the regularization of the spatial
%   gradient of the image in Equation 6 of Baek et al. 2017. `weights(2)`
%   is the 'beta' weight on the regularization of the spectral gradient of
%   the spatial gradient of the image in Equation 6 of Baek et al. 2017.
%   `weights(3)` is a weight on the regularization of the spatial Laplacian of
%   the image, as used in Song et al. 2016.
%
%   Values of zero in `weights` indicate that the corresponding
%   regularization terms are disabled. Note that if all elements of
%   `weights` are zero, and `options.nonneg` is `false`,
%   'baek2017Algorithm2LowMemory()' will throw an error, as image
%   estimation in this case is expected to be handled by the caller.
%
%   In the call syntax where `weights` is one of only three input arguments,
%   the value of `weights` must have the same pattern of zeros as in the
%   call which initialized `out`. (In other words, it must agree with
%   `enabled_weights`, documented below.)
%
% enabled_weights -- Regularization term statuses
%   A logical vector indicating which regularization terms are active.
%   `enabled_weights` is equivalent to `weights ~= 0`, except that passing
%   `weights` allows this function to finish calculating the 'A_const'
%   field of `out`. `enabled_weights` can be passed instead of `weights` to
%   save some computation for later (to be done using the call syntax where
%   `weights` is one of only three input arguments).
%
% options -- Options and small parameters
%   A structure with the following fields:
%   - 'rho': A three or four-element vector containing penalty parameters
%     used in the ADMM framework. The first three elements correspond to
%     the regularization terms. The fourth element is a penalty parameter
%     for a non-negativity constraint on the solution, and is only required
%     if the 'nonneg' field is `true`.
%   - 'full_GLambda': A Boolean value used as the `replicate` input
%     argument of 'spectralGradient()' when creating the spectral gradient
%     matrix for regularizing the spectral dimension of the latent image.
%     Refer to the documentation of 'spectralGradient.m' for details.
%     'full_GLambda' is not used if spectral regularization is disabled
%     (when `weights(2) == 0` is `true`).
%   - 'norms': A three-element logical vector, corresponding to the
%     regularization terms. Each element specifies whether to use the L1
%     norm (`true`) or an L2 norm (`false`) of the corresponding
%     regularization penalty vector. If some elements of 'norms' are
%     `false`, the ADMM iterations are simplified by eliminating slack
%     variables. If all elements are `false`, and 'nonneg' is `false`, then
%     ADMM reduces to a least-squares solution.
%   - 'nonneg': A Boolean scalar specifying whether or not to enable a
%     non-negativity constraint on the estimated image. If `true`, 'rho'
%     must have four elements.
%   - 'tol': A two-element vector containing convergence tolerances. The
%     first element is the tolerance value to use with MATLAB's 'pcg()'
%     function, such as when solving the I-minimization step of the ADMM
%     algorithm. The second element is the relative tolerance value for the ADMM
%     algorithm, as explained in Section 3.3.1 of Boyd et al. 2011. This
%     function will use the second element to compute an absolute tolerance
%     for the ADMM algorithm (`out.absolute_tol`).
%
% out -- Preallocated arrays and intermediate data
%   The `in` input/output argument of 'baek2017Algorithm2LowMemory()'.
%   Refer to the documentation of baek2017Algorithm2LowMemory.m.
%
%   `out` was initialized by a previous call to this function.
%
% ## Output Arguments
%
% out -- Preallocated arrays and intermediate data
%   The `in` input/output argument of 'baek2017Algorithm2LowMemory()'.
%   Refer to the documentation of baek2017Algorithm2LowMemory.m.
%
%   This function adds fields not used by 'baek2017Algorithm2LowMemory()':
%   - 'Omega': The colour space conversion matrix, mapping the vectorized
%     latent image to a vector in the colour space of the input image.
%   - 'Omega_Phi': The colour space conversion and warping matrix,
%     which applies dispersion to the vectorized latent image, and converts
%     the image to the colour space of the input image.
%   - 'M': The mosaicking matrix, mapping the vectorized form of the full
%     colour image (`Omega * I`) to a colour-filter array format.
%   - 'A_const_noWeights': A partial computation of 'A' which is
%     independent of the ADMM penalty parameters, and of the regularization
%     weights.
%
%   The 'A_const' field will only be initialized/updated when `weights` is
%   passed.
%
% weights -- Normalized regularization weights
%   A version of the `weights` input argument where each regularization
%   weight has been normalized by the length of the vector whose norm is
%   the regularization term to which it corresponds.
%
% ## References
%
% Refer to the references of 'baek2017Algorithm2LowMemory.m'.
%
% See also baek2017Algorithm2LowMemory, baek2017Algorithm2, mosaicMatrix,
% channelConversionMatrix, spatialGradient, spectralGradient, spatialLaplacian

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created October 9, 2018

if nargin == 6
    compute_all = true;
    J_2D = varargin{1};
    image_sampling = [size(J_2D, 1), size(J_2D, 2)];
    align = varargin{2};
    dispersion_matrix = varargin{3};
    sensitivity = varargin{4};
    n_bands = size(sensitivity, 2);
    no_weights = islogical(varargin{5});
    if no_weights
        nargoutchk(1, 1);
        enabled_weights = varargin{5};
    else
        nargoutchk(2, 2);
        weights = varargin{5};
    end
    options = varargin{6};
elseif nargin == 3
    nargoutchk(2, 2);
    no_weights = false;
    compute_all = false;
    out = varargin{1};
    weights = varargin{2};
    options = varargin{3};
elseif nargin == 1
    out = varargin{1};
    out.I = zeros(size(out.I));
    return;
else
    error('Unexpected number of input arguments.')
end

n_priors = 3;
nonneg_ind = 4;
if ~no_weights
    enabled_weights = (weights ~= 0);
end

if length(enabled_weights) ~= n_priors
    error('Expected `weights`/`enabled_weights` to have length %d for the %d prior terms.', n_priors, n_priors);
end
if ~no_weights && any(weights < 0)
    error('All elements of `weights` must be non-negative numbers.');
end

if ~compute_all
    for w = 1:n_priors
        if enabled_weights(w) == isempty(out.G{w})
            error('The set of enabled regularization terms has changed since `out` was created.');
        end
    end
end

norms = options.norms;
if length(norms) ~= n_priors
    error('Expected `options.norms` to have length %d for the %d prior terms.', n_priors, n_priors);
end

% Don't use ADMM to optimize priors given zero weight
norms(~enabled_weights) = false;

if compute_all
    nonneg = options.nonneg;

    rho = options.rho;
    if nonneg && length(rho) < nonneg_ind
        error('A %d-th penalty parameter must be provided in `rho` when `options.nonneg` is `true`.', nonneg_ind);
    elseif length(rho) < n_priors
        error('Expected `rho` to have length at least %d for the %d prior terms.', n_priors, n_priors);
    end
    if any(rho <= 0)
        error('The penalty parameters, `rho`, must be positive numbers.');
    end

    n_elements_I = prod(image_sampling) * n_bands;
    out.Omega = channelConversionMatrix(image_sampling, sensitivity);
    out.Omega_Phi = out.Omega;
    
    has_dispersion = ~isempty(dispersion_matrix);
    if has_dispersion
        if isfloat(dispersion_matrix) && ismatrix(dispersion_matrix)
            if size(dispersion_matrix, 1) ~= size(out.Omega, 1)
                error('`dispersion_matrix` must have as many rows as there are values in `J`.');
            elseif size(dispersion_matrix, 2) ~= n_elements_I
                error('`dispersion_matrix` must have as many columns as there are values in `I`.');
            end
        else
            error('`dispersion_matrix` must be a floating-point matrix.');
        end
        out.Omega_Phi = dispersion_matrix;
    end

    out.G = cell(n_priors, 1); 
    if enabled_weights(1) || enabled_weights(2)
         G_xy = spatialGradient([image_sampling, n_bands]);
         if enabled_weights(1)
             out.G{1} = G_xy;
         end
    end
    if enabled_weights(2)
        G_lambda = spectralGradient([image_sampling, n_bands], options.full_GLambda);
        G_lambda_sz1 = size(G_lambda, 1);
        G_lambda_sz2 = size(G_lambda, 2);
        % The product `G_lambda * G_xy` must be defined, so `G_lambda` needs to be
        % replicated to operate on both the x and y-gradients.
        out.G{2} = [
            G_lambda, sparse(G_lambda_sz1, G_lambda_sz2);
            sparse(G_lambda_sz1, G_lambda_sz2), G_lambda
            ] * G_xy;
    end
    if enabled_weights(3)
        out.G{3} = spatialLaplacian([image_sampling, n_bands]);
    end

    out.M = mosaicMatrix(image_sampling, align);
    out.M_Omega_Phi = out.M * out.Omega_Phi;
    
    out.J = reshape(J_2D, [], 1);
    
    % Compute a conservative absolute convergence tolerance that reflects the
    % magnitude of a typical value in the latent image.
    %
    % Suppose that the latent image has a uniform spectral intensity, and
    % therefore the intensity in each colour channel is the product of the sum
    % of the spectral sensitivity of that colour channel and the intensity of
    % the latent image. Find the median intensity in the raw image, and assume
    % that it corresponds to the colour channel with the highest mean spectral
    % sensitivity, then find the corresponding uniform spectral intensity. Set
    % an absolute convergence tolerance as the product of the relative
    % convergence tolerance and this uniform spectral intensity.
    out.absolute_tol = options.tol(2) * median(out.J) ./ max(sum(sensitivity, 2));

    out.M_Omega_Phi_J = zeros(n_elements_I, 1);
    out.G_T = cell(n_priors, 1);
    out.G_2 = cell(n_priors, 1);
    for w = 1:n_priors
        if enabled_weights(w)
            out.G_T{w} = out.G{w}.';
            out.G_2{w} = (out.G{w}.' * out.G{w});
        end
    end
    
    out.A_const_noWeights = (out.M_Omega_Phi.' * out.M_Omega_Phi);
    
    if nonneg
        out.I_A = speye(size(out.A_const_noWeights));
    end

    out.A = sparse(size(out.A_const_noWeights, 1), size(out.A_const_noWeights, 2));
    out.b = zeros(n_elements_I, 1);

    out.I = zeros(n_elements_I, 1);

    active_constraints = [norms, nonneg];
    n_Z = find(active_constraints, 1, 'last');

    out.Z = cell(n_Z, 1);
    out.U = cell(n_Z, 1);
    out.g = cell(n_Z, 1);
    out.Z_prev = cell(n_Z, 1);
    out.R = cell(n_Z, 1);
    out.Y = cell(n_Z, 1);

    for z_ind = 1:n_Z
        if active_constraints(z_ind)
            if z_ind == nonneg_ind
                len_Z = n_elements_I;
            else
                len_Z = size(out.G{z_ind}, 1);
            end
            out.Z{z_ind} = zeros(len_Z, 1);
            out.U{z_ind} = zeros(len_Z, 1);
            out.g{z_ind} = zeros(len_Z, 1);
            out.Z_prev{z_ind} = zeros(len_Z, 1);
            out.R{z_ind} = zeros(len_Z, 1);
            out.Y{z_ind} = zeros(len_Z, 1);
        end
    end

end

if ~no_weights
    % Adjust the weights so that they have the same relative importance
    % regardless of the differences in the lengths of the vectors whose norms
    % are being weighted.
    for w = 1:n_priors
        if enabled_weights(w)
            weights(w) = weights(w) * size(out.M_Omega_Phi, 1) / size(out.G{w}, 1);
        end
    end

    out.A_const = out.A_const_noWeights;
    for w = 1:n_priors
        if enabled_weights(w) && ~norms(w)
            out.A_const = out.A_const + weights(w) * out.G_2{w};
        end
    end
end

end