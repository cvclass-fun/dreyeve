%   This script computes the mean reprojection error (in terms of euclidean distance)
%   introduced by the homography estimation when projecting from garmin to
%   garmin

clear; close all; clc;

% Add packages to path
addpath(genpath('homography_utils'));
addpath(genpath('vlfeat-0.9.20'));

% Parameters
dreyeve_data_root = '/majinbu/public/DREYEVE/DATA';
n_frames = 100; % number of sampled frames for each sequence

all_errors      = []; % collection of all errors

% Loop over sequences
for seq=1:74
    
    % Root for this sequence
    seq_root = fullfile(dreyeve_data_root, sprintf('%02d', seq));
    
    % List etg and garmin sift files
    sift_etg_li = dir(fullfile(seq_root, 'etg', 'sift', '*.mat'));
    sift_gar_li = dir(fullfile(seq_root, 'sift', '*.mat'));
    
    % Loop over list
    for f=1:n_frames
        
        fprintf(1, sprintf('Sequence %02d, frame %06d of %06d...\n', seq, f, n_frames));
        
        % Extract frame index
        f_idx = randi([0, 7499]);
        
        % Load sift files for both etg and garmin
        load(fullfile(seq_root, 'etg', 'sift', sift_etg_li(f_idx).name));
        load(fullfile(seq_root, 'sift', sift_gar_li(f_idx).name));
        
        % Compute matches
        [matches, scores] = vl_ubcmatch(sift_etg.d1,sift_gar.d1);
        
        % Prepare data in homogeneous coordinates for RANSAC
        X1 = sift_etg.f1(1:2, matches(1,:)); X1(3,:) = 1; X1([1 2], :) = X1([1 2], :)*2;
        X2 = sift_gar.f1(1:2, matches(2,:)); X2(3,:) = 1; X2([1 2], :) = X2([1 2], :)*2;
        
        try
            % Fit ransac and find homography
            [H, ok] = ransacfithomography(X1, X2, 0.05);
            if size(ok, 2) >= 8
                
                % Extract only matches that homography considers inliers
                X1 = X1(:, ok);
                X2 = X2(:, ok);
                
                % Project
                X1_proj = H * X1;
                X1_proj = X1_proj ./ repmat(X1_proj(3, :), 3, 1);
                
                % Compute error
                errors = sqrt(sum((X1_proj - X2).^2, 1));
                errors(isnan(errors)) = [];
                
                all_errors = [all_errors; errors'];
            end
        catch ME
            warning('Catched exception, skipping some frames');
        end
    end
end

histogram(all_errors, 100, 'Normalization', 'pdf');
xlabel('Projection Error (ED)')
ylabel('Probability')
title('Distribution of errors etg->gar')
saveas(gcf, 'error_distribution_etg_to_gar')



