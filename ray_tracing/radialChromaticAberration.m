function [ disparity_spline, disparity_raw ] = radialChromaticAberration(...
    stats, reference_wavelength_index, z, reference_z, varargin...
)
% RADIALCHROMATICABERRATION  Model chromatic aberration
%
% ## Syntax
% disparity_spline = radialChromaticAberration(...
%     stats, reference_wavelength_index,...
%     z, reference_z [, wavelengths, wavelengths_to_rgb]...
% )
% [ disparity_spline, disparity ] = radialChromaticAberration(...
%     stats, reference_wavelength_index,...
%     z, reference_z [, wavelengths, wavelengths_to_rgb]...
% )
%
% ## Description
% disparity_spline = radialChromaticAberration(...
%     stats, reference_wavelength_index,...
%     z, reference_z [, wavelengths, wavelengths_to_rgb]...
% )
%   Returns a spline model of chromatic aberration as a function of
%   distance from the origin, and scene depth.
%
% [ disparity_spline, disparity ] = radialChromaticAberration(...
%     stats, reference_wavelength_index,...
%     z, reference_z [, wavelengths, wavelengths_to_rgb]...
% )
%   Additionally returns the disparity values used to build the spline
%   model.
%
% ## Input Arguments
%
% stats -- Point spread function statistics
%   Statistics of point spread functions produced by a set of scene
%   features, for each wavelength, and for each depth. `stats(i, k,
%   j).(name)` is the value of the 'name' statistic corresponding to the
%   i-th scene feature, emitting light the k-th wavelength, and positioned
%   at the j-th depth.
%
%   `stats.(name)` can be a scalars or vectors, as long as all elements are
%   the same size. Vectors will be converted to distances from the origin
%   when producing the first input variable used for spline fitting. (The
%   other input variable is the scene depth value.) The lengths of
%   differences between vectors at the reference wavelength, and vectors at
%   other wavelengths, will be used as the response variable values for
%   spline fitting.
%
%   Consequently, this function can generate trends in a variety of
%   quantities with respect to scene depth, such as image positions
%   (2-element vectors), and point spread function blur radii (scalars).
%
%   `stats` might be an array of the `stats` output argument of
%   'analyzePSF()', for example.
%
% reference_wavelength_index -- Reference wavelength
%   The index into the second dimension of `stats` representing the
%   reference wavelength. Chromatic aberration will be measured between
%   statistics produced with other wavelengths and statistics produced with
%   this wavelength.
%
% z -- Scene depths
%   The z-positions of the scene elements producing the values in `stats`.
%   `z` is a vector with a length equal to `size(stats, 3)`.
%
%   `z` can be some transformation of the actual z-positions. More
%   generally, `z` is some variable describing positions, measured along
%   the optical axis, which is to be assessed as a predictor of chromatic
%   aberration.
%
% reference_z -- Reference depth
%   The z-position corresponding to a depth value of zero; An offset which
%   will be applied to the values in `z`.
%
% wavelengths -- Wavelengths corresponding to image measurements
%   The wavelengths of light corresponding to the elements of `stats`. A
%   row vector of length `size(stats, 2)`, where `wavelengths(k)` is the wavelength
%   used to generate the values in `stats(:, k, :)`. This
%   parameter is used for figure legends only, not for calculations.
%
%   If both `wavelengths` and `wavelengths_to_rgb` are passed, graphical
%   output will be generated.
%
% wavelengths_to_rgb -- Colour map for wavelengths
%   RGB colours to be used when plotting points representing values for the
%   different wavelengths. The k-th row of this `size(stats, 2)` x 3
%   matrix represents the RGB colour corresponding to the k-th wavelength,
%   `wavelengths(k)`.
%
%   If both `wavelengths` and `wavelengths_to_rgb` are passed, graphical
%   output will be generated.
%
% ## Output Arguments
%
% disparity_spline -- Thin-plate spline models of chromatic aberration
%   A set of thin-plate smoothing splines modeling chromatic aberration as
%   a function of `z`, and `r`. In the case of image positions, `r` is the
%   2D distance in the image plane, of an image point from the origin,
%   where the image point was formed by light at the reference wavelength.
%   More generally, `r` is the distance of a value in `stats.(name)` from
%   the origin.
%
%   `disparity_spline.(name)` is a list of length `size(stats, 2)`, where
%   the k-th cell contains a thin-plate smoothing spline describing the
%   aberration between the k-th wavelength and the reference wavelength,
%   for the statistic 'name'.
%   `disparity_spline(reference_wavelength_index).(name)` is an empty cell.
%
%   `aberration = fnval(disparity_spline(k).(name),[r; z])` evaluates the
%   spline model at the distances from the origin in the row vector `r`,
%   and the associated depths in the row vector `z`. `aberration` is a row
%   vector of distances between point spread function statistics of type
%   'name'.
%
%   If there are too few data points to estimate spline models, all
%   elements of `disparity_spline.(name)` are empty cells.
%
% disparity_raw -- Input disparity values
%   The disparity values, calculated from the values in `stats` and `z`,
%   used to construct `disparity_spline`. `disparity_raw` has the same
%   dimensions as `stats`; `disparity_raw(i, k, j)` is the displacement
%   vector from `stats(i, reference_wavelength_index, j).(name)` to
%   `stats(i, k, j).(name)`. This disparity vector is therefore measured
%   for the i-th scene feature, emitting light at the k-th wavelength, and
%   positioned at the j-th depth.
%
% See also doubleSphericalLensPSF, analyzePSF, tpaps

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created June 27, 2017

nargoutchk(1, 2);
narginchk(4, 6);

if ~isempty(varargin)
    if length(varargin) ~= 2
        error('Unexpected number of input arguments. Note that both `wavelengths` and `wavelengths_to_rgb` should be passed, or neither should be passed.');
    else
        wavelengths = varargin{1};
        wavelengths_to_rgb = varargin{2};
        verbose = true;
    end
else
    verbose = false;
end

names = fieldnames(stats);
n_names = length(names);

sz = size(stats);
n_points = sz(1);
n_wavelengths = sz(2);
n_depths = sz(3);

if verbose
    n_points_all_depths = n_points * n_depths;
    disparity_z_plot = zeros(n_points_all_depths, 1);
end

stats_cell = struct2cell(stats);

z_adjusted = z - reference_z;
z_adjusted = repelem(z_adjusted, n_points);
if size(z_adjusted, 1) > size(z_adjusted, 2)
    z_adjusted = z_adjusted.';
end

for i = 1:n_names
    name_display_i = replace(names{i}, '_', '\_');
    stats_cell_i = squeeze(stats_cell(i, :, :, :));
    stats_cell_i = reshape(stats_cell_i, n_points, 1, n_wavelengths, n_depths);
    stats_mat_i = cell2mat(stats_cell_i);
    
    stats_reference_i = repmat(...
        stats_mat_i(:, :, reference_wavelength_index, :),...
        1, 1, n_wavelengths, 1 ...
    );
    disparity_raw_i = stats_mat_i - stats_reference_i;
    dimensionality = size(stats_mat_i, 2);

    if verbose && (dimensionality == 2 || dimensionality == 1)
        stats_mat_i_3D = reshape(permute(stats_mat_i, [1, 4, 2, 3]), [], dimensionality, n_wavelengths);
        disparity_raw_i_3D = reshape(permute(disparity_raw_i, [1, 4, 2, 3]), [], dimensionality, n_wavelengths);

        figure
        hold on
        legend_strings = cell(n_wavelengths * 2 - 1, 1);
        for k = 1:n_wavelengths
            if dimensionality == 2
                scatter3(...
                    stats_mat_i_3D(:, 1, k), stats_mat_i_3D(:, 2, k),...
                    z_adjusted, [], wavelengths_to_rgb(k, :), 'o'...
                );
            elseif dimensionality == 1
                scatter(...
                    stats_mat_i_3D(:, 1, k),...
                    z_adjusted, [], wavelengths_to_rgb(k, :), 'o'...
                );
            end
            legend_strings{k} = sprintf(...
                'Values for \\lambda = %g nm',...
                wavelengths(k)...
            );
        end
        k_legend = 1;
        for k = 1:n_wavelengths
            if k ~= reference_wavelength_index
                if dimensionality == 2
                    quiver3(...
                        stats_mat_i_3D(:, 1, reference_wavelength_index),...
                        stats_mat_i_3D(:, 2, reference_wavelength_index),...
                        z_adjusted.',...
                        disparity_raw_i_3D(:, 1, k),...
                        disparity_raw_i_3D(:, 2, k),...
                        disparity_z_plot,...
                        'Color', wavelengths_to_rgb(k, :), 'AutoScale', 'off'...
                    );
                elseif dimensionality == 1
                    quiver(...
                        stats_mat_i_3D(:, 1, reference_wavelength_index),...
                        z_adjusted.',...
                        disparity_raw_i_3D(:, 1, k),...
                        disparity_z_plot,...
                        'Color', wavelengths_to_rgb(k, :), 'AutoScale', 'off'...
                    );
                end
                legend_strings{n_wavelengths + k_legend} = sprintf(...
                    'Aberration for \\lambda = %g nm', wavelengths(k)...
                );
                k_legend = k_legend + 1;
            end
        end
        legend(legend_strings);
        title(sprintf('Values and aberrations for the ''%s'' statistic', name_display_i))
        if dimensionality == 2
            xlabel('Value dimension 1 (e.g. X)');
            ylabel('Value dimension 2 (e.g. y)');
            zlabel('Depth')
        elseif dimensionality == 1
            xlabel('Value');
            ylabel('Depth')
        end
        hold off
    elseif verbose
        warning('`radialChromaticAberration` cannot produce a visualization of statistics with more than two dimensions.');
    end

    disparity_raw_i_radial = sqrt(dot(disparity_raw_i, disparity_raw_i, 2));
    disparity_raw_i_radial_signs = sign(dot(stats_reference_i, disparity_raw_i, 2));
    disparity_raw_i_radial_signs(disparity_raw_i_radial_signs == 0) = 1;
    disparity_raw_i_radial = disparity_raw_i_radial .* disparity_raw_i_radial_signs;
    stats_reference_i_radial = sqrt(dot(...
        stats_mat_i(:, :, reference_wavelength_index, :),...
        stats_mat_i(:, :, reference_wavelength_index, :),...
        2 ...
    ));
    stats_reference_i_radial = stats_reference_i_radial(:).';

    % Prepare data for spline fitting
    spline_predictors = [ stats_reference_i_radial; z_adjusted ];
    spline_responses = permute(squeeze(disparity_raw_i_radial), [1, 3, 2]);
    spline_responses = reshape(spline_responses, 1, [], n_wavelengths);

    spline_predictors_filter = all(isfinite(spline_predictors), 1);
    spline_predictors = spline_predictors(:, spline_predictors_filter);
    spline_responses = spline_responses(:, spline_predictors_filter, :);

    % Spline fitting
    disparity_spline_i = cell(n_wavelengths, 1);
    for k = 1:n_wavelengths
        if k ~= reference_wavelength_index

            spline_responses_k = spline_responses(:, :, k);
            spline_responses_filter = isfinite(spline_responses_k);
            spline_responses_k = spline_responses_k(spline_responses_filter);
            spline_predictors_k = spline_predictors(:, spline_responses_filter);
            spline_predictors_unique = unique(spline_predictors_k(1, :));
            sufficient_data = (length(spline_predictors_unique) > 1);
            spline_predictors_unique = unique(spline_predictors_k(2, :));
            sufficient_data = sufficient_data & (length(spline_predictors_unique) > 1);

            if sufficient_data
                disparity_spline_i{k} = tpaps(...
                    spline_predictors_k,...
                    spline_responses_k...
                );
            else
                warning('Insufficient data points available to construct a spline model in radial position and depth for \\lambda = %g nm.', wavelengths(k))
            end

            if verbose
                figure
                if sufficient_data
                    pts = fnplt(disparity_spline_i{k});
                    surf(pts{1}, pts{2}, pts{3}, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
                    colorbar
                    colormap summer
                    c = colorbar;
                    c.Label.String = 'Disparity';
                    title(sprintf(...
                        'Aberration in %s for \\lambda = %g nm',...
                        name_display_i, wavelengths(k)...
                    ))
                    legend_str = {'Thin plate spline'};
                else
                    title(sprintf(...
                        'Aberration in %s for \\lambda = %g nm (Insufficient data for spline model)',...
                        name_display_i, wavelengths(k)...
                    ))
                    legend_str = {};
                end
                xlabel('Distance from the origin');
                ylabel('Depth');
                zlabel('Disparity');
                hold on
                plot3(...
                    spline_predictors_k(1, :), spline_predictors_k(2, :),...
                    spline_responses_k,...
                    'ko','markerfacecolor','r'...
                    )
                legend([legend_str, 'Original data points'])
                hold off
            end
        end
    end
    
    disparity_spline.(names{i}) = disparity_spline_i;
    disparity_raw.(names{i}) = disparity_raw_i;
end

end