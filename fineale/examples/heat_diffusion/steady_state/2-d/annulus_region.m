% Heat flux through an annulus region.
alltim = timetic(); tic(alltim);
kappa=0.2*[1.0 0; 0 1.0]; % conductivity matrix
magn = 0.06;
rin= 1.0;
rex= 2.0;
nr=10; nc=80;
Angle=2*pi;
thickness= 1.0;
tolerance=min([rin/nr,rin/nc/2/pi])/10000+rex/1e6;

tim = timetic(); tic(tim);
[fens,fes] = Q4_annulus(rin,rex,nr,nc,Angle,thickness);
%          drawmesh({fens,fes},'nodes','facecolor','r')
[fens,fes] = merge_nodes(fens, fes, tolerance);
edge_fes = mesh_boundary (fes,struct('other_dimension', thickness ));
toc(tim)


tim = timetic(); tic(tim);
% Compose the model data
clear model_data
model_data.fens =fens;

clear region
region.conductivity =kappa;
region.fes= fes;
region.integration_rule = gauss_rule(struct('order',2,'dim', 2));
model_data.region{1} =region;

clear flux
flux.normal_flux=-magn;
l1=fe_select(fens,edge_fes,struct('box',[-1.1*rex -0.9*rex -0.5*rex 0.5*rex]));
flux.fes = subset(edge_fes,l1);
flux.integration_rule = gauss_rule(struct('order',2,'dim', 1));
model_data.boundary_conditions.flux{1} = flux;

clear flux
flux.normal_flux=+magn;
l2=fe_select(fens,edge_fes,struct('box',[0.9*rex 1.1*rex -0.5*rex 0.5*rex]));
flux.fes = subset(edge_fes,l2);
flux.integration_rule = gauss_rule(struct('order',2,'dim', 1));
model_data.boundary_conditions.flux{2} = flux;

clear essential
essential.temperature=0.0;
essential.node_list=fenode_select(fens,struct('box',[0 0 -rex -rex],'inflate',tolerance));
model_data.boundary_conditions.essential{1} = essential;


% Solve
model_data =heat_diffusion_steady_state(model_data);
toc(tim)

%
model_data.postprocessing.z_scale = 1;
% model_data.postprocessing.camera =[ 325.7121 -164.7175   21.8267   24.2132   12.8789   -0.6138         0         0    1.0000    7.3068];
model_data =heat_diffusion_plot_raised_surface(model_data);

toc(alltim)