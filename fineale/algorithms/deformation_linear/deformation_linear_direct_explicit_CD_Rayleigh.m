function model_data = deformation_linear_direct_explicit_CD_Rayleigh(model_data)
% Direct-integration explicit solver for mechanical deformation.
%
% Algorithm for dynamic linear deformation with explicit  (centered-difference)
% direct integration. Rayleigh damping may be specified.
%
% function model_data = deformation_linear_direct_explicit_CD_Rayleigh(model_data)
%
% Arguments
% model_data = struct  with fields as follows.
%
% model_data.fens = finite element node set (mandatory)
%
% For each region (connected piece of the domain made of a particular material),
% mandatory:
% model_data.region= cell array of struct with the attributes, each region 
%           gets a struct with attributes
%     fes= finite element set that covers the region
%     integration_rule =integration rule
%     property = material property hint (optional): 'isotropic' (default), 
%           'orthotropic',...
%        For isotropic property (default):
%     E = material Young's modulus
%     nu = material Poisson's ratio
%        For orthotropic property:
%     E1, E2, E3 = material Young's modulus 
%           in the three material directions
%     G12, G13, G23 = material shear modulus 
%           between the three material directions
%     nu12, nu13, nu23 = material Poisson's ratio
%     rho = mass density (optional for statics, mandatory for dynamics)
%        If the region is for a two-dimensional model (plane strain, plane
%        stress, or axially symmetric) the attribute reduction  needs to be
%        specified.
%     reduction = 'strain' or 'stress' or 'axisymm'
%
%        If the material orientation matrix is not the identity and needs
%        to be supplied,  include the attribute
%     Rm= constant orientation matrix or a handle  to a function to compute
%           the orientation matrix (see the class femm_base).
%
% Example:
%     clear region
%     region.E =E;
%     region.nu=nu;
%     region.fes= fes;
%     region.integration_rule = gauss_rule (struct('dim', 3, 'order', 2));
%     model_data.region{1} =region;
%
% Example:
%     clear region
%     region.property = 'orthotropic';
%     region.rho =rho;
%     region.E1 =E1;     region.E2 =E2;     region.E3 =E3;
%     region.G12=G12;     region.G13=G13;     region.G23=G23;
%     region.nu12=nu12;     region.nu13=nu13;     region.nu23=nu23;
%     region.fes= fes;% set of finite elements for the interior of the domain
%     region.integration_rule = gauss_rule (struct('dim', 3, 'order', 2));
%     region.Rm =@LayerRm;
%     model_data.region{1} =region;
%
% For essential boundary conditions (optional):
% model_data.boundary_conditions.essential = cell array of struct,
%           each piece of surface with essential boundary condition gets one
%           element of the array with a struct with the attributes
%           as recognized by the set_ebc() method of nodal_field
%     is_fixed=is the degree of freedom being prescribed or 
%           freed? (boolean)
%     component=which component is affected (if not supplied, 
%           or if supplied as empty default is all components)
%     fixed_value=fixed (prescribed) displacement (scalar or function handle)
%     fes = finite element set on the boundary to which 
%                       the condition applies
%               or alternatively
%     node_list = list of nodes on the boundary to which 
%                       the condition applies
%           Only one of fes and node_list needs to be given.
%    
% Example:
%     clear essential
%     essential.component= [1,3];
%     essential.fixed_value= 0;
%     essential.node_list = [[fenode_select(fens, struct('box', [0,a,0,0,-Inf,Inf],...
%         'inflate',tolerance))],[fenode_select(fens, struct('box', [0,a,b,b,-Inf,Inf],...
%         'inflate',tolerance))]];;
%     model_data.boundary_conditions.essential{2} = essential;
%
% Example:
%     clear essential
%     essential.component= [1];
%     essential.fixed_value= 0;
%     essential.fes = mesh_boundary(fes);
%     model_data.boundary_conditions.essential{1} = essential;
%
% For traction boundary conditions (optional):
% model_data.boundary_conditions.traction = cell array of struct,
%           each piece of surface with traction boundary condition gets one
%           element of the array with a struct with the attributes
%     traction=traction (vector), supply a zero for component in which 
%           the boundary condition is inactive
%     fes = finite element set on the boundary to which 
%                       the condition applies
%     integration_rule= integration rule
%
% Example:
%     clear traction
%     traction.fes =subset(bdry_fes,bclx);
%     traction.traction= @(x) ([sigmaxx(x);sigmaxy(x);0]);
%     traction.integration_rule =gauss_rule(struct('dim', 2,'order', 2));%<==
%     model_data.boundary_conditions.traction{1} = traction;
%    
%
% For initial condition:
% model_data.initial_condition = struct with the attribute
%     u_fixed_value=initial displacement as a single
%           vector value (for instance [0,0,-1]) or
%           as a function of the location array geom.values to return the
%           initial displacement at each node; for example
%                 u_fixed_value= f, where
%                     f=@(x)0*x+ones(size(x,1),1)*[-0.02,0,0];
%           Note that x is an array,  one row per node.
%     v_fixed_value=initial velocity as a single
%           vector value (for instance [0,0,-1]) or
%           as a function of the location array geom.values to return the
%           initial velocity at each node; for example
%                 v_fixed_value= f, where
%                     f=@(x)0*x+ones(size(x,1),1)*[0,0,vmag];
%           Note that x is an array,  one row per node.
%
% Example:
%     clear initial_condition
%     initial_condition.u_fixed_value= @(x)0*x;
%     initial_condition.v_fixed_value= @(x)0*x;
%     model_data.initial_condition = initial_condition;
%
% Control parameters:
% The following attributes  may be supplied as fields of the model_data struct:
%      tend= end of the integration interval (mandatory)
%      step_reduction=the algorithm computes the stable time step for
%           explicit integration.  The time step than may be modified (increased)
%           by multiplying it with step_reduction.  Default is step_reduction=1.0.
%      observer = handle of an observer function (optional)
%           The observer function has a signature
%                     function output(t, model_data)
%           where t is the current time
%      Rayleigh_stiffness= multiplier of the stiffness matrix to obtain
%           the stiffness-proportional damping matrix. For a given loss factor
%           at a certain  frequency, the stiffness-proportional damping
%           coefficient may be estimated as
%                Rayleigh_stiffness = 2*loss_tangent/(2*pi*frequency);
%      Rayleigh_mass= multiplier of the mass matrix to obtain
%           the mass-proportional damping matrix. For a given loss factor
%           at a certain  frequency, the mass-proportional damping
%           coefficient may be estimated as
%                Rayleigh_mass = 2*loss_tangent*(2*pi*frequency);
%
% Output
% model_data = updated structure that was given on input updated as:
% It incorporates in addition to the input the nodal_fields
%     geom = geometry field
%     u = displacement field
 
    
%     Control parameters
Rayleigh_stiffness =0;
if ( isfield(model_data,'Rayleigh_stiffness'))
    Rayleigh_stiffness  =model_data.Rayleigh_stiffness;;
end
Rayleigh_mass =0;
if ( isfield(model_data,'Rayleigh_mass'))
    Rayleigh_mass  =model_data.Rayleigh_mass;;
end
observer =@(t,model_data) disp(['Time ' num2str(t)]);
if ( isfield(model_data,'observer'))
    observer  =model_data.observer;;
end
step_reduction =0.99;
if ( isfield(model_data,'step_reduction'))
    step_reduction  =model_data.step_reduction;;
end
dt =[];
if ( isfield(model_data,'dt'))
    dt  =model_data.dt;;
end
tend =0;
if ( isfield(model_data,'tend'))
    tend  =model_data.tend;;
end
implicit_solve = false;
if ( isfield(model_data,'implicit_solve'))
    implicit_solve  =model_data.implicit_solve;;
end
maxit =3;%  Number of iterations in the solution for accelerations
%     Accelerations are computed  with tolerance equal to
%     acceleration_tolerance*( norm of initial guess of acceleration)
acceleration_tolerance =1e-3;%
% Extract the nodes
fens =model_data.fens;

% Construct the geometry field
model_data.geom = nodal_field(struct('name',['geom'], 'dim', fens.dim, 'fens', fens));

% Construct the displacement field
model_data.u = nodal_field(struct('name',['u'], 'dim', model_data.geom.dim, 'nfens', model_data.geom.nfens));

% Apply the essential boundary conditions on the displacement field
if isfield(model_data,'boundary_conditions')...
        && (isfield(model_data.boundary_conditions, 'essential' ))
    for j=1:length(model_data.boundary_conditions.essential)
        essential =model_data.boundary_conditions.essential{j};
        if (isfield( essential, 'fes' ))
            essential.fenids= connected_nodes(essential.fes);
        else
            essential.fenids= essential.node_list;
        end
        if (~isfield( essential, 'is_fixed' )) || isempty(essential.is_fixed)
            essential.is_fixed=ones(length(essential.fenids),1);
        end
        if (~isfield( essential, 'component' )) || isempty(essential.component)
            essential.component =1:model_data.u.dim;
        end
        fixed_value =0;
        if (isfield( essential, 'fixed_value' ))
            fixed_value = essential.fixed_value;
        end
        val=zeros(length(essential.fenids),1)+fixed_value;
        for k=1:length( essential.component)
            model_data.u = set_ebc(model_data.u, essential.fenids, essential.is_fixed, essential.component(k), val);
        end
        model_data.u = apply_ebc (model_data.u);
        % If the essential boundary condition is to be time-dependent, the
        % values must be supplied by a function.   Find out…
        essential.time_dependent =(isa(essential.fixed_value,'function_handle'));
        model_data.boundary_conditions.essential{j} =essential;
    end
    clear essential fenids fixed component fixed_value  val
end

% Number the equations: The displacements may be prescribed
model_data.u = numberdofs (model_data.u);
% and that would also be reflected in the velocity vector..
model_data.v = model_data.u;

% Construct the system stiffness and mass matrix
K=  sparse(model_data.u.nfreedofs,model_data.u.nfreedofs);
M=  sparse(model_data.u.nfreedofs,model_data.u.nfreedofs);
for i=1:length(model_data.region)
    region =model_data.region{i};
    if (~isfield( region, 'femm'))
        if (isfield(region, 'property' ))
            if (strcmp( region.  property, 'orthotropic' ))
                prop = property_deformation_linear_ortho (...
                    struct('E1',region.E1,'E2',region.E2,'E3',region.E3,...
                    'G12',region.G12,'G13',region.G13,'G23',region.G23,...
                    'nu12',region.nu12,'nu13',region.nu13,'nu23',region.nu23,'rho',region.rho));
            elseif (strcmp( region.  property, 'isotropic' ))
                prop=property_deformation_linear_iso(struct('E',region.E,'nu',region.nu,'rho',region.rho));
            else% default
                prop=property_deformation_linear_iso(struct('E',region.E,'nu',region.nu,'rho',region.rho));
            end
        else
            prop=property_deformation_linear_iso(struct('E',region.E,'nu',region.nu));
        end
        prop.rho=region.rho;
        if (model_data.u.dim==1)
            mater = material_deformation_linear_uniax (struct('property',prop ));
        elseif (model_data.u.dim==2)
            mater = material_deformation_linear_biax (struct('property',prop, ...
                'reduction',region.reduction));
        else
            mater = material_deformation_linear_triax (struct('property',prop ));
        end
        Rm = [];
        if (isfield( region, 'Rm'))
            Rm= region.Rm;
        end
        region.femm = femm_deformation_linear (struct ('material',mater,...
            'fes',region.fes,...
            'integration_rule',region.integration_rule,'Rm',Rm));
    end
    % Give the  FEMM a chance  to precompute  geometry-related quantities
    region.femm = associate_geometry(region.femm,model_data.geom);
    K = K + stiffness(region.femm, sysmat_assembler_sparse, model_data.geom, model_data.u);
    M = M + lumped_mass(region.femm, sysmat_assembler_sparse, model_data.geom, model_data.u);
    model_data.region{i}=region;
    clear region Q prop mater Rm  femm
end
C=  Rayleigh_stiffness*K + Rayleigh_mass*M;%  Compute the damping matrix
Cdiag = spdiags(C,0);
Crest = spdiags(zeros(size(C,1),1),0,C);
Cdiag = spdiags(Cdiag,0,size(C,1),size(C,2)) ;


% Process the traction boundary condition
if (isfield(model_data.boundary_conditions, 'traction' ))
    for j=1:length(model_data.boundary_conditions.traction)
        traction =model_data.boundary_conditions.traction{j};
        traction.femm = femm_deformation_linear (struct ('material',[],...
            'fes',traction.fes,...
            'integration_rule',traction.integration_rule));
        % If the traction boundary condition is to be time-dependent, the
        % values must be supplied by a function.   Find out!
        traction.time_dependent =(isa(traction.traction,'function_handle'));
        model_data.boundary_conditions.traction{j}=traction;
    end
    clear traction fi  femm
end

%     Set the initial condition
if isfield(model_data,'initial_condition')
    if (isa(model_data.initial_condition.u_fixed_value,'function_handle'))
        model_data.u.values = model_data.initial_condition.u_fixed_value(model_data.geom.values);
    else
        uval=gather_sysvec(model_data.u)*0+model_data.initial_condition.u_fixed_value;
        model_data.u = scatter_sysvec(model_data.u,uval);
    end
    if (isa(model_data.initial_condition.v_fixed_value,'function_handle'))
        model_data.v.values = model_data.initial_condition.v_fixed_value(model_data.geom.values);
    else
        vval=gather_sysvec(model_data.v)*0+model_data.initial_condition.v_fixed_value;
        model_data.v = scatter_sysvec(model_data.v,uval);
    end
else % no initial conditions were supplied, assume  all displacements and velocities are zero.
    model_data.u=gather_sysvec(model_data.u)*0;
    model_data.v=gather_sysvec(model_data.v)*0;
end

% Solve
% Find the stable time step.  Compute the largest eigenvalue (angular
% frequency of vibration), and determine the time step from it.
if isempty(dt)
    o2=eigs(K,M,1,'LM');
    dt= step_reduction* 2/sqrt(o2);
end
model_data.dt=dt;

% b=is_diagonally_dominant((M+dt/2*C));
% if (~b)
%     warning ('Fixed iteration is  probably not going to work as M+dt/2*C is not diagonally dominant');
% end

% Let us begin:
t=0;
% Initial displacement, velocity, and acceleration.
U0 = gather_sysvec(model_data.u);
V0= gather_sysvec(model_data.v);
A0 =[];% The acceleration will be computed from the initial loads.
F0 = 0*U0;% Zero out the load
% Process the time-independent traction boundary condition
if (isfield(model_data.boundary_conditions, 'traction' ))
    for j=1:length(model_data.boundary_conditions.traction)
        traction =model_data.boundary_conditions.traction{j};
        if (~traction.time_dependent)
            fi= force_intensity(struct('magn',traction.traction));
            F0 = F0 + distrib_loads(traction.femm, sysvec_assembler, model_data.geom, model_data.u, fi, 2);
        end
    end
    clear traction fi
end
%         % Process time-dependent essential boundary conditions:
if ( isfield(model_data,'boundary_conditions')) && ...
        (isfield(model_data.boundary_conditions, 'essential' ))
    for j=1:length(model_data.boundary_conditions.essential)
        essential =model_data.boundary_conditions.essential{j};
        if (~essential.time_dependent)% this needs to be computed
            % only for truly time-independent EBC. The field needs to be
            % cleared of fixed values for each specification of the
            % essential boundary conditions in order not to apply them
            % twice.
            fixed_value =essential.fixed_value;
            for k=1:length(essential.component)
                model_data.u = set_ebc(model_data.u, essential.fenids, ...
                    essential.is_fixed, essential.component(k), fixed_value);
            end
            model_data.u = apply_ebc (model_data.u);
            for i=1:length(model_data.region)
                F0 = F0 + nz_ebc_loads(model_data.region{i}.femm, sysvec_assembler, model_data.geom, model_data.u);
            end
            model_data.u.fixed_values(:)=0;% Zero out the fixed values for the next load
        end
    end
    clear essential
end
% This is the time-independent load vector
F0indep=F0;
%     First output is the initial condition
if ~isempty(observer)% report the progress
    observer (t,model_data);
end
step =0;
while t <tend
    t=t+dt;
    step = step  +1;
    F0 = 0*F0;% Zero out the load
    F0 = F0 + F0indep;% Add on the time-independent load vector
    %         % Process time-dependent essential boundary conditions:
    if ( isfield(model_data,'boundary_conditions')) && ...
            (isfield(model_data.boundary_conditions, 'essential' ))
        Any_essential_time_dependent =false;;
        for j=1:length(model_data.boundary_conditions.essential)
            essential =model_data.boundary_conditions.essential{j};
            if (essential.time_dependent)% this needs to be computed
                % only for truly time-dependent EBC
                Any_essential_time_dependent =true;;
                if (isa(essential.fixed_value,'function_handle'))
                    fixed_value =essential.fixed_value(t);
                else
                    fixed_value =essential.fixed_value;
                end
                for k=1:length(essential.component)
                    model_data.u = set_ebc(model_data.u, essential.fenids, ...
                        essential.is_fixed, essential.component(k), fixed_value);
                end
                model_data.u = apply_ebc (model_data.u);
            end
        end
        clear essential
        % Add the loads due to fixed displacements
        if (Any_essential_time_dependent)% Only if any time-dependent
            for i=1:length(model_data.region)
                F0 = F0 + nz_ebc_loads(model_data.region{i}.femm, sysvec_assembler, model_data.geom, model_data.u);
                % Add the loads due to fixed displacements and damping [to be done]
            end
        end
    end
    % If this is the first step compute the initial acceleration.
    if (isempty(A0))
        A0=M\F0;
    end
    % Process the traction boundary condition
    if (isfield(model_data.boundary_conditions, 'traction' ))
        for j=1:length(model_data.boundary_conditions.traction)
            traction =model_data.boundary_conditions.traction{j};
            if (traction.time_dependent)
                fi= force_intensity(struct('magn',traction.traction(t)));
                F0 = F0 + distrib_loads(traction.femm, sysvec_assembler, model_data.geom, model_data.u, fi, 2);
            end
        end
        clear traction fi
    end
    % Update  of the displacement and velocity
    U1 = U0 +dt*V0+(dt^2)/2*A0;% displacement update
    % Compute the new acceleration.
    if ( implicit_solve )
        A1 = (M +(dt/2)*C)\(F0-K*U1-C*(V0+(dt/2)*A0));
    else
        % Use fixed-point iteration to incorporate
        % general damping. The new acceleration is the solution of
        %         A1 = (M +(dt/2)*C)\(F0-K*U1-C*(V0+(dt/2)*A0));
        % but to solve this equation would be expensive for the explicit
        % integrator with its small time step.  Therefore we attempt to use
        % fixed-point iteration.  If the number of iterations is small the
        % technique will be effective;  however it may fail to converge.
        rp=(F0-K*U1-C*(V0+(dt/2)*A0));% iteration-independent, for efficiency
        A1 = (M+dt/2*Cdiag)\(rp-dt/2*Crest*A0);% predictor
        nA1=norm(A1);
        for it=1:maxit % fixed-point iteration
            pA1=A1;
            A1 = (M+dt/2*Cdiag)\(rp - (dt/2)*Crest*A1);
            npA1A1 =norm(pA1-A1);
            %                 disp(num2str(npA1A1/nA1))
            if npA1A1 <= acceleration_tolerance*nA1
                break;
            end
        end
        if npA1A1 > acceleration_tolerance*nA1
            %             warning(['Fixed-point iteration did not converge, implicit solve used']);
            A1 = (M +(dt/2)*C)\(F0-K*U1-C*(V0+(dt/2)*A0));
        end
    end
    % Update the velocity
    V1 = V0 +dt/2* (A0+A1);
    % Bring the the displacement and velocity fields up to date
    model_data.u = scatter_sysvec(model_data.u, U1);
    model_data.v = scatter_sysvec(model_data.v, V1);
    % Switch the temporary vectors for the next step.
    U0 = U1;
    V0 = V1;
    A0 = A1;
    if (t==tend)
        break;
    end
    if (t+dt>tend) % Adjust the last time step so that we exactly reach tend
        dt =tend-t;
    end
    if ~isempty(observer)% report the progress
        observer (t,model_data);
    end
end

end
