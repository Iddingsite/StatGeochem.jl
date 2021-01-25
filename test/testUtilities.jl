
## --- Resampling.jl

    @test bsr(1:10,fill(0.5,10),1000,0.5)::Array{Float64} |> length == 1000
    @test bsr(1:10,fill(0.5,10),1000,fill(0.5,10))::Array{Float64} |> length == 1000
    @test bsr!(Array{Int64}(undef,1000),1:10,fill(0,10),1000,0.5) |> unique ⊆ 1:10
    @test bsr!(Array{Int64}(undef,1000),1:10,fill(0,10),1000,fill(0.5,1000)) |> unique ⊆ 1:10

    @test bincounts(1:100,0,100,10) == (5:10:95, fill(10,10))
    @test binmeans(1:100,1:100,0,100,10) == (5:10:95, 5.5:10:95.5, fill(0.9574271077563381,10))
    @test binmedians(1:100,1:100,0,100,10) == (5:10:95, 5.5:10:95.5, fill(1.1720982147414096,10))

    @test randsample(1:10,1000)::Array{Int64} |> length == 1000
    @test unique(randsample(1:10,1000)) ⊆ 1:10

    # Invweight...

## --- Geochemistry.jl

    @test eustar(6.5433, 5.9037) ≈ 2.0329978601003864
    @test eustar(34.7773, 6.5433, 5.9037, 0.8904) ≈ 2.0825737578695205

    @test CIA(14.8577, 4.5611, 3.29641, 2.3992) ≈ 47.66582778067264
    @test WIP(3.2964, 4.5611, 2.3992, 5.9121) ≈ 78.40320264846837

    @test tzirc(58.509, 1.022, 14.858, 4.371, 0.141, 4.561, 5.912, 3.296, 2.399, 0.279, 100) ≈ 602.8489762809595
    @test tzircZr(58.509, 1.022, 14.858, 4.371, 0.141, 4.561, 5.912, 3.296, 2.399, 0.279, 800) ≈ 832.9689080567883

    @test tsphene(58.509, 1.022, 14.858, 4.371, 0.141, 4.561, 5.912, 3.296, 2.399, 0.279) ≈ 637.139776663209
    @test tspheneTi(58.509, 1.022, 14.858, 4.371, 0.141, 4.561, 5.912, 3.296, 2.399, 0.279, 800) ≈ 2.3545537746637324

    @test feoconversion(3.5, NaN, NaN, NaN) == 3.5
    @test feoconversion(3.5, NaN, 7.5, NaN) == 7.5
    @test feoconversion(3.5, NaN, 7.5, 10) == 7.5
    @test feoconversion(3.5, 4.4, NaN, NaN) ≈ 7.45916511675966
    @test feoconversion(NaN, 4.4, NaN, NaN) ≈ 3.9591651167596607

    D = elementify(["Fe" "Mg" "Ca" "P"; 10000 10000 10000 10000; 10000 10000 10000 10000], importas=:Dict)
    D = oxideconversion(D)
    @test all(D["FeOT"] .≈ (molarmass["Fe"]+molarmass["O"])/molarmass["Fe"])
    @test all(D["MgO"] .≈ (molarmass["Mg"]+molarmass["O"])/molarmass["Mg"])
    @test all(D["CaO"] .≈ (molarmass["Ca"]+molarmass["O"])/molarmass["Ca"])
    @test all(D["P2O5"] .≈ (molarmass["P"]+2.5*molarmass["O"])/molarmass["P"])


## --- Geochronology.jl

    @test eHf(0.2818792, 0.001009289, 1424.878) ≈ -0.9639408985107067

    (c, m, el, eu) = bin_bsr_eHf(1:4000, fill(0.2818792, 4000), fill(0.001009289,4000), 1:4000, 0, 4000, 4, fill(10,4000), fill(0.001,4000), fill(1e-6,4000), fill(10,4000), 500)
    @test c == 500:1000:3500
    isapprox(m, [-21.316, 0.724, 23.187, 45.97], atol=5)
    isapprox(el, [2.254, 2.216, 2.28, 2.319], atol=0.5)
    isapprox(eu, [2.245, 2.216, 2.273, 2.348], atol=0.5)

## --- GIS.jl

   A = [6 10 3 10; 5 1 4 2; 8 10 5 5; 9 1 1 10]
   @test Int64.(maxslope(A*1000, 1:4, 1:4, 1)) == [0 81 13 0; 36 16 16 32; 51 16 29 38; 0 81 57 0]
   @test Int64.(aveslope(A*1000, 1:4, 1:4, 1)) == [0 0 6 0; 14 22 9 14; 25 0 14 12; 0 28 12 0]

   grid =
   """
   ncols         4
   nrows         6
   xllcorner     0.0
   yllcorner     0.0
   cellsize      50.0
   NODATA_value  -9999
   -9999 -9999 5 2
   -9999 20 100 36
   3 8 35 10
   32 42 50 6
   88 75 27 9
   13 5 1 -9999
   """

   f = open("grid.asc","w")
   print(f, grid)
   close(f)

   (data, metadata) = importAAIGrid("grid.asc", Int64, undefval=-999)
   @test eltype(data) == Int64
   @test data == [-9999 -9999 5 2; -9999 20 100 36; 3 8 35 10; 32 42 50 6; 88 75 27 9; 13 5 1 -9999]
   @test metadata["nodata"] == -9999

## ---
