function run_tests()
arguments
end
f={@test_sensor,@test_order,@test_poly,@test_grid,@test_cov,@test_tre,@test_end};
for i=1:numel(f)
    fprintf('Running %s ... ',func2str(f{i}));
    f{i}();
    fprintf('ok\n');
end
fprintf('All MATLAB RSM reference tests passed.\n');
end
