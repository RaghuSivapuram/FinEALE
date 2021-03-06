function perforated_strip_prescribed_displacement
    disp('Perforated_strip, prescribed displacement: ss J2 plasticity');
    % Parameters:
    E=7000;
    nu=0.3;
    sigma_y=24.3;
    L= 360; % Length of the beam
    W = 10; % Thickness of the plate
    H = 200; % Width
    R= 100;
    nL=8;nH=4;nR=4;
    umag=2.5;
    scale=20;
    stressscale=scale/20;
    epscale=2*scale;
    nincr =15;
    utol = 10e-7;
    graphics = true;
maxdu_tol = W/1e7;
    
    
    %  Create the mesh and initialize the geometry
    [fens,fes]=Q4_elliphole(R,R,L,H,nL,nH,nR,[]);
    [fens,fes] = H8_extrude_Q4(fens,fes,1,@(x,i)([x,0]+[0,0,W*i]));
    [fens,fes] = H8_to_H20(fens,fes);
    
    
    
    % Package model data
    clear model_data;
    model_data.fens =fens;
    
    
    clear region
    prop = property_deformation_linear_iso (struct('E',E,'nu',nu));
    prop = property_deformation_plastic_perf_j2_iso(struct('E',E,'nu',nu,'sigma_y',sigma_y));
    mater = material_deformation_ss_plastic_perf_j2_triax(struct('property',prop));
    region.femm= femm_deformation_nonlinear(...
        struct ('material',mater,...
        'fes',fes, ...
        'integration_rule',gauss_rule(struct('dim',3,'order',3))));;
    model_data.region{1} =region;
    
    %  Clamped cross-section
    clear essential
    essential.component= [1];
    essential.fixed_value= 0;
    essential.node_list = fenode_select (fens,struct('box',[0,0,-Inf,Inf,-Inf,Inf],'inflate',W/1000));
    model_data.boundary_conditions.essential{1} = essential;
    clear essential
    essential.component= [2];
    essential.fixed_value= 0;
    essential.node_list = fenode_select (fens,struct('box',[-Inf,Inf,0,0,-Inf,Inf],'inflate',W/1000));
    model_data.boundary_conditions.essential{2} = essential;
    clear essential
    essential.component= [3];
    essential.fixed_value= 0;
    essential.node_list = fenode_select (fens,struct('box',[-Inf,Inf,-Inf,Inf,0,0],'inflate',W/1000));
    model_data.boundary_conditions.essential{3} = essential;
    % This face is displaced by a given amount
    clear essential
    essential.component= [1];
    essential.fixed_value= @(lambda)lambda*umag;
    essential.node_list = fenode_select (fens,struct('box',[L,L,-Inf,Inf,-Inf,Inf],'inflate',W/1000));
    model_data.boundary_conditions.essential{4} = essential;
    
      % If online graphics  is needed, initialize some variables
      if (graphics),
          bdry_fes = mesh_boundary(fes, []);
          sfemm = femm_deformation (struct ('material',[], 'fes',bdry_fes,...
              'integration_rule',[]));
          gv=reset(clear(graphic_viewer,[]),[]);
          cmap = jet;
          Cam= 1.0e+03 *[-0.9065   -1.3161    1.0356    0.1802    0.1000    0.0050         0         0    0.0010    0.0078
              ];
    end
    
    % Select the solver options
    model_data.load_multipliers=(1:nincr)/nincr*1.0;
    model_data.maxdu_tol  =maxdu_tol;;
    model_data.line_search  = true;
    model_data.iteration_observer =@iteration_observer;
    us={};
    model_data.load_increment_observer =@load_increment_observer;
    % Call the nonlinear deformation solver
    model_data =deformation_nonlinear_statics(model_data);
    
    %     Report results
    %     Center_fenids=fenode_select (fens,struct('box',[L,L,W/2, W/2,-Inf,Inf],'inflate',1/1000));
    %     u1s=[];
    %     for j=1:length(us)
    %         u1s=[u1s,mean(gather_values(us{j},enl))];
    %     end
    %     u1s  =reshape(u1s',[3,nincr])';
    
    % Observer function to be called when convergence is reached.
    function load_increment_observer(lambda,model_data)
        fprintf(1,'\n');
        if 0 && graphics
            gv=reset(clear(gv,[]),[]);
            draw(sfemm,gv, struct ('x', model_data.geom, 'u', 0*model_data.u,'facecolor','none', 'shrink',1.0));
            draw(sfemm,gv, struct ('x', model_data.geom, 'u', model_data.u,'facecolor','y', 'shrink',1.0));
            camset (gv,Cam);
            interact(gv);
            pause(0.5); Cam =camget(gv);
        end
        us{end+1} =model_data.un1;
    end
    
    % Iteration of observer can be called as the solution is being computed.
    function iteration_observer(lambda,iter,du,model_data)
        fprintf(1,'%d: %g\n',iter,norm(du));
        %         if 1 && graphics
        %             gv=reset(clear(gv,[]),[]);
        %             draw(sfemm,gv, struct ('x', model_data.geom, 'u', 0*model_data.u,'facecolor','none', 'shrink',1.0));
        %             draw(sfemm,gv, struct ('x', model_data.geom, 'u', scale*model_data.u,'facecolor','y', 'shrink',1.0));
        %             camset (gv,Cam);
        %             interact(gv);
        %             pause(0.5); Cam =camget(gv);
        %         end
        id.comp= 1;
        id.container=-Inf;
        id=inspect_integration_points(model_data.region{1}.femm, model_data.geom, model_data.un1, model_data.un, model_data.dt, [],...
            (1:length (fes)), struct ('output',['equiv_pl_def']),...
            @mx,id);
        max_equiv_pl_def=id.container;
        id.container=Inf;
        id=inspect_integration_points(model_data.region{1}.femm, model_data.geom, model_data.un1, model_data.un, model_data.dt, [], ...
            (1:length (fes)), struct ('output',['equiv_pl_def']),...
            @mn,id);
        min_equiv_pl_def =id.container;
        dcm=data_colormap(struct ('range',[min_equiv_pl_def,max_equiv_pl_def], 'colormap',jet));
        gv=reset(clear(gv,[]),[]);
        title (['Iteration ' num2str(iter)  ])
        camset (gv,1.0e+003 *[ -2.1416   -1.4296    3.3375    0.1981    0.1191   -0.0063    0.0006    0.0004    0.0006 0.0039]);
        draw(model_data.region{1}.femm,gv, struct ('x', model_data.geom,...
            'u',scale*model_data.un1, 'facecolor','none'));
        draw_integration_points(model_data.region{1}.femm,gv,struct ('x',model_data.geom,...
            'un1',model_data.un1,'un',model_data.un,'dt',model_data.dt,...
            'u_scale',scale, 'scale',epscale,'output',['equiv_pl_def'],'component',1,'data_cmap', dcm));
        drawnow; 
        pause(0.1)
        
        function id= mn(id,out,xyz,U,pc)
            id.container=min(out(id.comp), id.container);
        end
        
        function id= mx(id,out,xyz,U,pc)
            id.container=max(out(id.comp), id.container);
        end
    end
    
end

%
%             id.comp= 1;
%             id.container=-Inf;
%             id=inspect_integration_points(feb, geom, u, [],...
%                 (1:length (gcells)), struct ('output',['equiv_pl_def']),...
%                 @mx,id);
%             max_equiv_pl_def=id.container
%             id.container=Inf;
%             id=inspect_integration_points(feb, geom, u, [], ...
%                 (1:length (gcells)), struct ('output',['equiv_pl_def']),...
%                 @mn,id);
%             min_equiv_pl_def =id.container
%             dcm=data_colormap(struct ('range',[min_equiv_pl_def,max_equiv_pl_def], 'colormap',jet));
%             gv=reset(clear(gv,[]),[]);
%             title (['Increment ' num2str(incr) ': Converged for t=' num2str(t) ])
%             camset (gv,1.0e+003 *[ -2.1416   -1.4296    3.3375    0.1981    0.1191   -0.0063    0.0006    0.0004    0.0006 0.0039]);
%             draw(feb,gv, struct ('x', geom,'u',scale*u, 'facecolor','none'));
%             draw_integration_points(feb,gv,struct ('x',geom,'u',u,'u_displ',scale*u, 'scale',epscale,'quantity',['equiv_pl_def'],'component',1,'data_cmap', dcm));
%             drawnow; pause(0.1)
%         end
%         disp(['Increment ' num2str(incr) ': Converged for t=' num2str(t) ]); % pause
%         Center_deflection = [Center_deflection,mean(Center_u(:,3))];
%         incr = incr + 1;
%     end
%     Center_deflection
%     camget (gv)
% end
%
% function id= mn(id,out,xyz,pc)
%     id.container=min(out(id.comp), id.container);
% end
%
% function id= mx(id,out,xyz,pc)
%     id.container=max(out(id.comp), id.container);
% end
% %draw(gmlin, 'dataidx', 3, 'scale', scale, 'displace_by', [1 2 3], 'facecolor', 'none')and
%
