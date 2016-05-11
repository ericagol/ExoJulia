using LsqFit
include("../compute_ttv.jl")
using TTVFaster
include("MCJulia.jl")
using PyPlot

"""
    ttvs(data)
Computer parameters for the planets passed in data.
#Arguments
* `data`: pass in any number of arrays containing transit data for each planet
#Return
* `result`: an Nx5 array where each row contains [mass_ratio, period, trans0, ecosw, esinw]
            where N is the number of planets
"""
function ttvs(p0, data...)
  num_planets = length(data)

  if num_planets < 2
    println("Error: must provide data for at least 2 planets")
    return
  end

  combined_data::Array{Float64} = [] #combine all the data into one array, which we'll fit all at once
  data_start_end = [] #store the start and end of each planet's data
  for pd in data
    combined_data = [combined_data;pd[:]]
    if length(data_start_end) == 0
      push!(data_start_end, ( 1,length(pd[:])) )
    else
      start = data_start_end[end][2]+1
      push!(data_start_end, ( start, start+length(pd[:]) -1 ) )
    end
  end

  function model_func(useless_input_x, params) #curve fit makes us take the first parameter

    planets = []

    for i=1:div(length(params),5)
      planet = Planet_plane_hk(params[5*i-4],params[5*i-3],params[5*i-2],params[5*i-1],params[5*i])
      push!(planets,planet)
    end

    results = zeros(length(combined_data))

    for i=1:num_planets-1
      ttv1 = zeros(data_start_end[i][2]-data_start_end[i][1] +1)
      ttv_data_p1 = collect(1:1:length(ttv1))
      ttv_data_p1 = ttv_data_p1 .* planets[i].period .+ planets[i].trans0
      for j=i+1:num_planets
        ttv2 = zeros(data_start_end[j][2]-data_start_end[j][1] +1)
        ttv_data_p2 = collect(1:1:length(ttv2))
        ttv_data_p2 = ttv_data_p2 .* planets[j].period .+ planets[j].trans0
        compute_ttv!(5,planets[i],planets[j],
            ttv_data_p1,
            ttv_data_p2,
            ttv1,ttv2);
        results[data_start_end[i][1]:data_start_end[i][2]] = results[data_start_end[i][1]:data_start_end[i][2]] + ttv1
        results[data_start_end[j][1]:data_start_end[j][2]] = results[data_start_end[j][1]:data_start_end[j][2]] + ttv2
      end
    end

    #convert the results array from ttvs back to periods for curve fit to compare against
    for i=1:num_planets
      d_start = data_start_end[i][1]
      d_end = data_start_end[i][2]
      for j=d_start:d_end
        results[j] = results[j] + (j - d_start)*planets[i].period + planets[i].trans0
      end
    end

    return results
  end

  fit = curve_fit(model_func, [], combined_data, p0)

  return fit
end

function third_planet()
  p1 = readdlm("../ttv_planet1.txt")
  p2 = readdlm("../ttv_planet2.txt")

  lh = []
  periods = collect(600:20:800)
  for period in periods
    for t0=1:10
      t0_val = t0*period/10 + p1[1]
      time = [t0_val, t0_val+period]

      param0 = [0.000003, 224, 8445, 0.0001, 0.0001,
                0.000003, 365, 8461, 0.0001, 0.0001,
                0.0000015, period, t0_val, 0.0001, 0.0001 ]
      fit = ttvs(param0, p1,p2,time)

      sigma = estimate_errors(fit, 0.95)[12]
      errors = fit.resid[12]
      lh_val = exp(-errors^2/(2*sigma^2))/(2*pi*sigma^2)^0.5
      push!(lh, (period, lh_val))
      end
  end
  # println(size(lh))
  scatter([x[1] for x in lh], [x[2] for x in lh])
  show()
  #call the MC MC solver
  #perr = [0.000002, 4, 5, 0.00005, 0.00005, 0.000002, 5, 5, 0.00005, 0.00005]
  #ye = ones((1,length(combined_data)))*30/24/3600
  #mc_results = aimc(model_func, [], fit.param, perr, combined_data, ye)

end

function test()
  p1 = readdlm("../ttv_planet1.txt")
  p2 = readdlm("../ttv_planet2.txt")

  param0 = [0.000003, 224, 8445, 0.0001, 0.0001, 0.000003, 365, 8461, 0.0001, 0.0001]
  fit = ttvs(param0, p1,p2)

  result = fit.param

  #println("m1=$(result[1]), period1=$(result[2]), m2=$(result[6]), p2=$(result[7])")
  return "m1=$(result[1][1]), period1=$(result[2][1]), m2=$(result[6][1]), p2=$(result[7][1])"
end

#println(test())
third_planet()