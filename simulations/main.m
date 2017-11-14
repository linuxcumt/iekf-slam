%% -----------------------------------------------------------------------------------------------
% %  Simulation script: 2D I-EKF SLAM SIMULATION
% %  Reference:
% %  - Guoquan Huang, Anastasios I. Mourikis and Stergios I. Roumeliotis.
% %    Observability-based Rules for Designing Consistent EKF SLAM Estimators.
% %    International Journal of Robotics Research, vol. 29, no. 5, pp. 502-528, April 2010.
% %
% %
% %  Written by:
% %  Martin Brossard <martin.brossard@mines-paristech.fr>
% %  Guoquan (Paul) Huang <ghuang@udel.edu>
%% -----------------------------------------------------------------------------------------------
clear all
close all
clc
J = [0 -1;1 0];

%% Simulation Parameters

v_true = .2;
omega_true = .025;
nL = 20; %number of landmarks
nSteps = 2500; %nubmer of time steps
nRuns = 10; %number of monte carlo runs

max_range = 5;
min_range = .5;
sigma = .05*v_true;
sigma_v = sigma/sqrt(2);
sigma_w = 2*sqrt(2)*sigma;
Q = diag([sigma_v^2 sigma_w^2]);
sigma_p = .1; %noise
dt = 1;
%% preallocate memory for saving resutls

% Ideal EKF
xRest_id = zeros(3,nSteps,nRuns); %estimated traj
xRerr_id = zeros(3,nSteps,nRuns); %all err state
Prr_id = zeros(3,nSteps,nRuns); %actually diag of Prr
neesR_id = zeros(1,nSteps,nRuns); %nees (or mahalanobis distance)
rmsRp_id =  zeros(1,nSteps,nRuns); %rms of robot position
rmsRth_id = zeros(1,nSteps,nRuns); %rms of robot orientation

% Standard EKF
xRest_std = zeros(3,nSteps,nRuns); %estimated traj
xRerr_std = zeros(3,nSteps,nRuns); %all err state
Prr_std = zeros(3,nSteps,nRuns); %actually diag of Prr
neesR_std = zeros(1,nSteps,nRuns); %nees (or mahalanobis distance)
rmsRp_std =  zeros(1,nSteps,nRuns); %rms of robot position
rmsRth_std = zeros(1,nSteps,nRuns); %rms of robot orientation

% IEKF
xRest_iekf = zeros(3,nSteps,nRuns); %estimated traj
xRerr_iekf = zeros(3,nSteps,nRuns); %all err state
Prr_iekf = zeros(3,nSteps,nRuns); %actually diag of Prr
neesR_iekf = zeros(1,nSteps,nRuns); %nees (or mahalanobis distance)
rmsRp_iekf =  zeros(1,nSteps,nRuns); %rms of robot position
rmsRth_iekf = zeros(1,nSteps,nRuns); %rms of robot orientation

% UKF
xRest_ukf = zeros(3,nSteps,nRuns); %estimated traj
xRerr_ukf = zeros(3,nSteps,nRuns); %all err state
Prr_ukf = zeros(3,nSteps,nRuns); %actually diag of Prr
neesR_ukf = zeros(1,nSteps,nRuns); %nees (or mahalanobis distance)
rmsRp_ukf =  zeros(1,nSteps,nRuns); %rms of robot position
rmsRth_ukf = zeros(1,nSteps,nRuns); %rms of robot orientation

% robocentric
xRest_rc = zeros(3,nSteps,nRuns); %estimated traj
xRerr_rc = zeros(3,nSteps,nRuns); %all err state
Prr_rc = zeros(3,nSteps,nRuns); %actually diag of Prr
neesR_rc = zeros(1,nSteps,nRuns); %nees (or mahalanobis distance)
rmsRp_rc =  zeros(1,nSteps,nRuns); %rms of robot position
rmsRth_rc = zeros(1,nSteps,nRuns); %rms of robot orientation

% OC-EKF
xRest_ocekf = zeros(3,nSteps,nRuns); %estimated traj
xRerr_ocekf = zeros(3,nSteps,nRuns); %all err state
Prr_ocekf = zeros(3,nSteps,nRuns); %actually diag of Prr
neesR_ocekf = zeros(1,nSteps,nRuns); %nees (or mahalanobis distance)
rmsRp_ocekf =  zeros(1,nSteps,nRuns); %rms of robot position
rmsRth_ocekf = zeros(1,nSteps,nRuns); %rms of robot orientation

% LANDMARK GENERATION: same landmarks in each run
xL_true_fixed = gen_map(nL,v_true,omega_true,min_range, max_range, nSteps,dt);%max_range=5

%% Monte Carlo Simulations
for kk = 1:nRuns
    
    disp(kk)
    
    % % real world simulation data % %
    xL_true(:,:,kk) = xL_true_fixed;
    [v_m,omega_m, v_true_all,omega_true_all, xR_true(:,:,kk), z,R] = rws(nSteps, dt,v_true,omega_true,sigma_v,sigma_w,sigma_p,xL_true(:,:,kk),max_range,min_range);
    
    
    % % INITIALIZATION
    x0 = zeros(3,1);
    P0 = zeros(3);
    
    % Ideal EKF
    xe_id = x0;
    Pe_id = P0;
    V_id = [];
    
    % Standard EKF
    xe_std = x0;
    Pe_std = P0;
    V_std = [];
    
    % Standard UKF
    xe_ukf = x0;
    Pe_ukf = P0 + eye(3)*10^-9; %to be positive
    
    % IEKF
    xe_iekf = x0;
    Pe_iekf = P0;
    
    % robocentric
    xe_rc = x0;
    xe_rc(3) = -xe_rc(3);
    xe_rc(1:2) = -rot(x0(3))'*x0(1:2);
    Pe_rc = P0;
    xe_rc_wc = zeros(3,1);
    xeL_rc_wc = zeros(2*nL,1);
    
    % OC-EKF
    xe_ocekf = x0;
    Pe_ocekf = P0;
    xL_ocekf = [];
    xR_oc_k_k1_1 = xe_ocekf(1:3,1);
    dpR_star_prev_1 = zeros(2,1);
    pR_star_prev = x0(1:2,1);
    dpR_ocekf = zeros(2,1);
    V_ocekf = [];
    PHI_mult_ocekf = eye(1);
    lambda_1 = zeros(2,nL);
    
    % list of landmark ids that sequentially appear in the state vector
    lm_seq_id = [];
    lm_seq_std = [];
    lm_seq_iekf = [];
    lm_seq_ocekf = [];
    lm_seq_ukf = [];
    lm_seq_rc = [];
    
    for k= 1:nSteps-1
        %first init_steps for ekf propagation to produce nonzero init cov
        
        % % PROPAGATE: k+1|k
        [xe_id,Pe_id,PHI_id,G_id] = propagate_id(xe_id,Pe_id,dt,v_m(k),omega_m(k),sigma_v,sigma_w,xR_true(:,k,kk),v_true_all(k),omega_true_all(k));
        [xe_std,Pe_std,PHI_std,G_std] = propagate_std(xe_std,Pe_std,dt,v_m(k),omega_m(k),sigma_v,sigma_w);
        [xe_ocekf,Pe_ocekf,PHI_ocekf,G_ocekf,PHI_mult_ocekf,  xR_oc_k_k1_1,dpR_star_prev_1,pR_star_prev,lambda_1] = propagate_ocekf(xe_ocekf,Pe_ocekf,dt,v_m(k),omega_m(k),sigma_v,sigma_w,PHI_mult_ocekf, xR_oc_k_k1_1,dpR_star_prev_1,pR_star_prev,xL_ocekf,lambda_1, lm_seq_ocekf,z(:,:,k+1));
        [xe_iekf,Pe_iekf,PHI_iekf,G_iekf] = propagate_iekf(xe_iekf,Pe_iekf,dt,v_m(k),omega_m(k),sigma_v,sigma_w);
        [xe_rc,Pe_rc] = propagate_rc(xe_rc,Pe_rc,dt,v_m(k),omega_m(k),sigma_v,sigma_w);
        [xe_ukf,Pe_ukf] = propagate_ukf(xe_ukf,Pe_ukf,dt,v_m(k),omega_m(k),sigma_v,sigma_w);
        
        % % UPDATE: k+1|k+1
        [xe_id,Pe_id,lm_seq_id,V_id] = update_id(xe_id,Pe_id,lm_seq_id,z(:,:,k+1),R{k+1},xR_true(:,k+1,kk),xL_true(:,:,kk), V_id,PHI_id);
        [xe_std,Pe_std,lm_seq_std] = update_std(xe_std,Pe_std,lm_seq_std,z(:,:,k+1),R{k+1});
        [xe_ocekf,Pe_ocekf,xL_ocekf,lm_seq_ocekf, V_ocekf,dpR_ocekf,lambda_1] = update_ocekf(xe_ocekf,Pe_ocekf,xL_ocekf,lm_seq_ocekf,z(:,:,k+1),R{k+1}, PHI_mult_ocekf,V_ocekf,dpR_ocekf, lambda_1, dpR_star_prev_1);
        [xe_iekf,Pe_iekf,lm_seq_iekf] = update_iekf(xe_iekf,Pe_iekf,lm_seq_iekf,z(:,:,k+1),R{k+1});
        [xe_rc,Pe_rc,lm_seq_rc] = update_rc(xe_rc,Pe_rc,lm_seq_rc,z(:,:,k+1),R{k+1},v_m(k),omega_m(k));
        xe_rc_wc(3) = -xe_rc(3);
        xe_rc_wc(1:2) = -rot(xe_rc(3))'*xe_rc(1:2);
        for jj = 1:(length(xe_rc)-3)/2
            xeL_rc_wc(2*jj-1:2*jj) = rot(-xe_rc_wc(3))'*xe_rc(3+2*jj-1:3+2*jj) + xe_rc_wc(1:2);
        end
        [xe_ukf,Pe_ukf,lm_seq_ukf] = update_ukf(xe_ukf,Pe_ukf,lm_seq_ukf,z(:,:,k+1),R{k+1});
        
        % % SAVE RESULTS
        % Ideal EKF
        xRest_id(:,k+1,kk) = xe_id(1:3,1);
        err = xR_true(1:3,k+1,kk) - xe_id(1:3,1);
        err(3) = pi_to_pi(err(3));
        xRerr_id(:,k+1,kk) = err;
        Prr_id(:,k+1,kk) = diag(Pe_id(1:3,1:3));
        neesR_id(:,k+1,kk) = err'*inv(Pe_id(1:3,1:3))*err;
        rmsRp_id(:,k+1,kk) = err(1:2,1)'*err(1:2,1);
        rmsRth_id(:,k+1,kk) = err(3,1)'*err(3,1);
        
        % Standard UKF
        xRest_ukf(:,k+1,kk) = xe_ukf(1:3,1);
        err = xR_true(1:3,k+1,kk) - xe_ukf(1:3,1);
        err(3) = pi_to_pi(err(3));
        xRerr_ukf(:,k+1,kk) = err;
        Prr_ukf(:,k+1,kk) = diag(Pe_ukf(1:3,1:3));
        neesR_ukf(:,k+1,kk) = err'*inv(Pe_ukf(1:3,1:3))*err;
        rmsRp_ukf(:,k+1,kk) = err(1:2,1)'*err(1:2,1);
        rmsRth_ukf(:,k+1,kk) = err(3,1)'*err(3,1);
        
        % Standard EKF
        xRest_std(:,k+1,kk) = xe_std(1:3,1);
        err = xR_true(1:3,k+1,kk) - xe_std(1:3,1);
        err(3) = pi_to_pi(err(3));
        xRerr_std(:,k+1,kk) = err;
        Prr_std(:,k+1,kk) = diag(Pe_std(1:3,1:3));
        neesR_std(:,k+1,kk) = err'*inv(Pe_std(1:3,1:3))*err;
        rmsRp_std(:,k+1,kk) = err(1:2,1)'*err(1:2,1);
        rmsRth_std(:,k+1,kk) = err(3,1)'*err(3,1);
        
        % Robocentric
        xRest_rc(:,k+1,kk) = xe_rc_wc(1:3);
        err = xR_true(1:3,k+1,kk) - xe_rc_wc(1:3);
        err(3) = pi_to_pi(err(3));
        xRerr_rc(:,k+1,kk) = err;
        Prr_rc(:,k+1,kk) = diag(Pe_rc(1:3,1:3));
        D = eye(3);
        D(3,3) = -1;
        D(1:2,1:2)  = -rot(xe_rc_wc(3));
        D(1:2,3)    = -J*xe_rc_wc(1:2);
        P_aux = D*Pe_rc(1:3,1:3)*D' ;
        
        neesR_rc(:,k+1,kk) = err'*inv(P_aux(1:3,1:3))*err;
        rmsRp_rc(:,k+1,kk) = err(1:2,1)'*err(1:2,1);
        rmsRth_rc(:,k+1,kk) = err(3,1)'*err(3,1);
        
        % IEKF
        xRest_iekf(:,k+1,kk) = xe_iekf(1:3,1);
        err = xR_true(1:3,k+1,kk) - xe_iekf(1:3,1);
        err(3) = pi_to_pi(err(3));
        xRerr_iekf(:,k+1,kk) = err;
        D = eye(3);
        D(1:2,3)   = J*xe_iekf(1:2,1);
        P_aux = D*Pe_iekf(1:3,1:3)*D';
        Prr_iekf(:,k+1,kk) = diag(P_aux);
        neesR_iekf(:,k+1,kk) = err'*inv(P_aux)*err;
        rmsRp_iekf(:,k+1,kk) = err(1:2,1)'*err(1:2,1);
        rmsRth_iekf(:,k+1,kk) = err(3,1)'*err(3,1);
        
        
        % OC-EKF
        xRest_ocekf(:,k+1,kk) = xe_ocekf(1:3,1);
        err = xR_true(1:3,k+1,kk) - xe_ocekf(1:3,1);
        err(3) = pi_to_pi(err(3));
        xRerr_ocekf(:,k+1,kk) = err;
        Prr_ocekf(:,k+1,kk) = diag(Pe_ocekf(1:3,1:3));
        neesR_ocekf(:,k+1,kk) = err'*inv(Pe_ocekf(1:3,1:3))*err;
        rmsRp_ocekf(:,k+1,kk) = err(1:2,1)'*err(1:2,1);
        rmsRth_ocekf(:,k+1,kk) = err(3,1)'*err(3,1);
    end%end of all nSteps
end%end of monte carlo runs


%% Monte Carlo Results
% % average nees and rms of robot pose over all runs
neesR_avg_std = sum(neesR_std,3)/nRuns;
neesR_avg_id = sum(neesR_id,3)/nRuns;
neesR_avg_iekf = sum(neesR_iekf,3)/nRuns;
neesR_avg_rc = sum(neesR_rc,3)/nRuns;
neesR_avg_ocekf = sum(neesR_ocekf,3)/nRuns;
neesR_avg_ukf = sum(neesR_ukf,3)/nRuns;

rmsRp_avg_std = sqrt(sum(rmsRp_std,3)/nRuns);
rmsRp_avg_id = sqrt(sum(rmsRp_id,3)/nRuns);
rmsRp_avg_iekf = sqrt(sum(rmsRp_iekf,3)/nRuns);
rmsRp_avg_rc = sqrt(sum(rmsRp_rc,3)/nRuns);
rmsRp_avg_ukf = sqrt(sum(rmsRp_ukf,3)/nRuns);
rmsRp_avg_ocekf = sqrt(sum(rmsRp_ocekf,3)/nRuns);

rmsRth_avg_std = sqrt(sum(rmsRth_std,3)/nRuns);
rmsRth_avg_id = sqrt(sum(rmsRth_id,3)/nRuns);
rmsRth_avg_iekf = sqrt(sum(rmsRth_iekf,3)/nRuns);
rmsRth_avg_ukf = sqrt(sum(rmsRth_ukf,3)/nRuns);
rmsRth_avg_rc = sqrt(sum(rmsRth_rc,3)/nRuns);
rmsRth_avg_ocekf = sqrt(sum(rmsRth_ocekf,3)/nRuns);

% % average robot pose err w/ cov
xRerr_avg_std = sum(xRerr_std,3)/nRuns;
xRerr_avg_id = sum(xRerr_id,3)/nRuns;
xRerr_avg_iekf = sum(xRerr_iekf,3)/nRuns;
xRerr_avg_ukf = sum(xRerr_ukf,3)/nRuns;
xRerr_avg_rc = sum(xRerr_rc,3)/nRuns;
xRerr_avg_ocekf = sum(xRerr_ocekf,3)/nRuns;

% % avg. robot cov
Prr_avg_std = sum(Prr_std,3)/nRuns;
Prr_avg_id = sum(Prr_id,3)/nRuns;
Prr_avg_iekf = sum(Prr_iekf,3)/nRuns;
Prr_avg_ukf = sum(Prr_ukf,3)/nRuns;
Prr_avg_rc = sum(Prr_rc,3)/nRuns;
Prr_avg_ocekf = sum(Prr_ocekf,3)/nRuns;


%% plot figures
plot_simu

