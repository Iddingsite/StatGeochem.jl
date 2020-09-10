## --- Fast inverse square-root

    """
    ```julia
    inv_sqrt(x)
    ```
    The fast inverse square root of `x`, in 32 and 64 bit versions. Can be up to
    10x faster than base `1/sqrt(x)`, though with significant loss of precision.
    The implementations here are good to about 4 ppm.
    """
    function inv_sqrt(x::Float64)
        x_2 = 0.5 * x
        result = Base.sub_int(9.603007803048109e153, Base.lshr_int(x,1)) # Floating point magic
        result *= ( 1.5 - (x_2 * result * result )) # Newton's method
        result *= ( 1.5 - (x_2 * result * result )) # Newton's method (again)
        return result
    end
    function inv_sqrt(x::Float32)
        x_2 = 0.5f0 * x
        result = Base.sub_int(1.321202f19, Base.lshr_int(x,1)) # Floating point magic
        result *= ( 1.5f0 - (x_2 * result * result) ) # Newton's method
        result *= ( 1.5f0 - (x_2 * result * result) ) # Newton's method (again)
        return result
    end

## --- Base-10 version of log1p

    function log10f(x::Number,from::Number=-1)
        return log10(abs(x-from)+1)*sign(x-from)
    end

## --- Gaussian distribution functions

    """
    ```julia
    normpdf(mu,sigma,x)
    ```
    Probability density function of the Normal (Gaussian) distribution

    ``ℯ^{-(x-μ)^2 / (2σ^2)} / σ√2π``

    with mean `mu` and standard deviation `sigma`, evaluated at `x`
    """
    normpdf(mu,sigma,x) = @. exp(-(x-mu)*(x-mu) / (2*sigma*sigma)) / (sqrt(2*pi)*sigma)
    export normpdf

    """
    ```julia
    normpdf_ll(mu, sigma, x)
    ```
    Fast log likelihood corresponding to a Normal (Gaussian) distribution
    with mean `mu` and standard deviation `sigma`, evaluated at `x`.

    If `x`, [`mu`, and `sigma`] are given as arrays, the sum of the log likelihood
    over all `x` will be returned.

    See also `normpdf`
    """
    normpdf_ll(mu::Number,sigma::Number,x::Number) = -(x-mu)*(x-mu) / (2*sigma*sigma)
    function normpdf_ll(mu::Number,sigma::Number,x::AbstractArray)
        ll = 0.0
        inv_s2 = 1/(2*sigma*sigma)
        @avx for i=1:length(x)
            ll -= (x[i]-mu)*(x[i]-mu) * inv_s2
        end
        return ll
    end
    function normpdf_ll(mu::AbstractArray,sigma::Number,x::AbstractArray)
        ll = 0.0
        inv_s2 = 1/(2*sigma*sigma)
        @avx for i=1:length(x)
            ll -= (x[i]-mu[i])*(x[i]-mu[i]) * inv_s2
        end
        return ll
    end
    function normpdf_ll(mu::Number,sigma::AbstractArray,x::AbstractArray)
        ll = 0.0
        @avx for i=1:length(x)
            ll -= (x[i]-mu)*(x[i]-mu) / (2*sigma[i]*sigma[i])
        end
        return ll
    end
    function normpdf_ll(mu::AbstractArray,sigma::AbstractArray,x::AbstractArray)
        ll = 0.0
        @avx for i=1:length(x)
            ll -= (x[i]-mu[i])*(x[i]-mu[i]) / (2*sigma[i]*sigma[i])
        end
        return ll
    end
    export normpdf_ll


    """
    ```julia
    normcdf(mu,sigma,x)
    ```
    Cumulative density function of the Normal (Gaussian) distribution

    ``1/2 + erf(\frac{x-μ}{σ√2})/2``

    with mean `mu` and standard deviation `sigma`, evaluated at `x`.
    """
    normcdf(mu::Number,sigma::Number,x::Number) = 0.5 + 0.5 * erf((x-mu) / (sigma*sqrt(2)))
    normcdf(mu,sigma,x) = @avx @. 0.5 + 0.5 * erf((x-mu) / (sigma*sqrt(2)))
    export normcdf

    """
    ```julia
    normcdf!(result,mu,sigma,x)
    ```
    In-place version of `normcdf`
    """
    function normcdf!(result::Array, mu::Number, sigma::Number, x::AbstractArray)
        T = eltype(result)
        inv_sigma_sqrt2 = one(T)/(sigma*sqrt(2))
        @avx for i ∈ 1:length(x)
            result[i] = T(0.5) + T(0.5) * erf((x[i]-mu) * inv_sigma_sqrt2)
        end
        return result
    end
    export normcdf!

    """
    ```julia
    norm_quantile(F::Number)
    ```
    How far away from the mean (in units of sigma) should we expect proportion
    F of the samples to fall in a standard Gaussian (Normal[0,1]) distribution
    """
    function norm_quantile(F::Number)
        return sqrt(2)*erfinv(2*F-1)
    end
    export norm_quantile

    """
    ```julia
    norm_width(N::Number)
    ```
    How dispersed (in units of sigma) should we expect a sample of N numbers
    drawn from a standard Gaussian (Normal[0,1]) distribution to be?
    """
    function norm_width(N::Number)
        F = 1 - 1/(N+1)
        return 2*norm_quantile(F)
    end
    export norm_width

    """
    ```julia
    normproduct(μ1, σ1, μ2, σ2)
    ```
    The integral of the product of two normal distributions N[μ1,σ1] * N[μ2,σ2].
    This is itself just another Normal distribution! Specifically, one with
    variance σ1^2 + σ2^2, evaluated at distance |μ1-μ2| from the mean
    """
    function normproduct(μ1::Number, σ1::Number, μ2::Number, σ2::Number)
        normpdf(μ1, sqrt(σ1^2 + σ2^2), μ2)
    end
    export normproduct

    """
    ```julia
    normproduct_ll(μ1, σ1, μ2, σ2)
    ```
    Log likelihood corresponding to the integral of N[μ1,σ1] * N[μ2,σ2]
    As `normproduct`, but using the fast log likelihood of a Normal distribution
    """
    function normproduct_ll(μ1::Number, σ1::Number, μ2::Number, σ2::Number)
        normpdf_ll(μ1, sqrt(σ1^2 + σ2^2), μ2)
    end
    export normproduct_ll


## --- Geometry

    """
    ```julia
    inpolygon(x,y,point)
    ```
    Check if a 2D polygon defined by the arrays `x`, `y` contains a given `point`.
    Returns boolean (true or false)
    """
    function inpolygon(x,y,point)
        # Check that we have the right kind of input data
        if length(x) != length(y)
            error("polygon must have equal number of x and y points\n")
        end
        if length(x) < 3
            error("polygon must have at least 3 points\n")
        end
        if length(point) != 2
            error("point must be an ordered pair (x,y)\n")
        end

        # Extract x and y data of point
        point_x = point[1]
        point_y = point[2]
        # For first point, previous point is last
        x_here = x[end]
        y_here = y[end]
        # Ensure we are not sitting parallel to a vertex by infinitessimally moving the point
        if y_here == point_y
            point_y = nextfloat(float(point_y))
        end
        if x_here == point_x
            point_x = nextfloat(float(point_x))
        end

        # Check how many times a line projected right along x-axis from point intersects the polygon
        intersections = 0
        @inbounds for i=1:length(x)
            # Recycle our vertex
            x_last = copy(x_here)
            y_last = copy(y_here)

            # Get a new vertex
            x_here = x[i]
            y_here = y[i]

            # Ensure we are not sitting parallel to a vertex by infinitessimally moving the point
            if y_here == point_y
                point_y = nextfloat(float(point_y))
            end
            if x_here == point_x
                point_x = nextfloat(float(point_x))
            end

            if y_last > point_y && y_here > point_y
                # If both ys above point, no intersection
                continue
            elseif y_last < point_y && y_here < point_y
                # If both ys below point, no intersection
                continue
            elseif x_last < point_x && x_here < point_x
                # If both x's left of point, no intersection
                continue
            elseif x_last > point_x && x_here > point_x
                # By elimination
                # We have one y above and y below our point
                # If both y's are right of line, then definite intersection
                intersections += 1
                continue
            else
                # By elimination
                # One y above and one y below
                # One x to the right and one x to the left
                # We must project
                dy = y_here - y_last
                if abs(dy) > 0
                    dx = x_here - x_last
                    inv_slope = dx / dy
                    x_proj = x_last + (point_y - y_last) * inv_slope
                    if x_proj > point_x
                        intersections += 1
                    end
                end
            end
        end

        # If number of intersections is odd, point is in the polygon
        return Bool(mod(intersections,2))
    end
    export inpolygon


    """
    ```julia
    (rows, columns) = find_grid_inpolygon(grid_x, grid_y, poly_x, poly_y)
    ```
    Find the indexes of grid points that fall within a polygon for a grid with
    cell centers given by grid_x (j-columns of grid) and grid_y (i-rows of grid).
    Returns a list of rows and columns in the polygon
    """
    function find_grid_inpolygon(grid_x, grid_y, poly_x, poly_y)
        # Check that we have the right kind of input data
        if length(poly_x) != length(poly_y)
            error("polygon must have equal number of x and y points\n")
        end
        if length(poly_x) < 3
            error("polygon must have at least 3 points\n")
        end

        # Find maximum x and y range of polygon
        (xmin, xmax) = extrema(poly_x)
        (ymin, ymax) = extrema(poly_y)

        # Find the matrix indices within the range of the polygon (if any)
        column_inrange = findall((grid_x .>= xmin) .& (grid_x .<= xmax))
        row_inrange = findall((grid_y .>= ymin) .& (grid_y .<= ymax))

        # Keep a list of matrix indexes in the polygon
        row = Array{Int}(undef,length(column_inrange) * length(row_inrange))
        column = Array{Int}(undef,length(column_inrange) * length(row_inrange))
        n = 0
        for j = 1:length(column_inrange)
            for i = 1:length(row_inrange)
                point = [grid_x[column_inrange[j]], grid_y[row_inrange[i]]]
                if inpolygon(poly_x, poly_y, point)
                    n += 1
                    row[n] = row_inrange[i]
                    column[n] = column_inrange[j]
                end
            end
        end

        return (row[1:n], column[1:n])
    end
    export find_grid_inpolygon


    """
    ```julia
    arcdistance(latᵢ,lonᵢ,lat,lon)
    ```
    Calculate the distance on a sphere between the point (`latᵢ`,`lonᵢ`) and any
    number of points in (`lat`,`lon`).
    Latitude and Longitude should be specified in decimal degrees
    """
    function arcdistance(latᵢ,lonᵢ,lat,lon)
        # Argument for acos()
        arg = sin.(latᵢ .* pi/180) .* sin.(lat .* pi/180) .+ cos.(latᵢ*pi/180) .* cos.(lat .* pi/180).*cos.((lonᵢ .- lon) .* pi/180)

        # Avoid domain errors from imprecise sine and cosine math
        arg[arg .> 1.0] .= 1.0
        arg[arg .< -1.0] .= -1.0

        # Calculate angular distance
        theta = 180/pi .* acos.(arg)
        return theta
    end
    export arcdistance

## --- Weighted mean of an array

    """
    ```julia
    (wx, wσ, mswd) = awmean(x, σ)
    ```
    Weighted mean, absent the geochonologist's MSWD correction to uncertainty.
    """
    function awmean(x, σ)
        n = length(x)

        sum_of_values = sum_of_weights = χ2 = 0.0
        @inbounds @simd for i=1:n
            sum_of_values += x[i] / (σ[i]*σ[i])
            sum_of_weights += 1 / (σ[i]*σ[i])
        end
        wx = sum_of_values / sum_of_weights

        @inbounds @simd for i=1:n
            χ2 += (x[i] - wx) * (x[i] - wx) / (σ[i] * σ[i])
        end
        mswd = χ2 / (n-1)
        wσ = sqrt(1.0 / sum_of_weights)
        return wx, wσ, mswd
    end
    function awmean(x::Array{<:Number}, σ::Array{<:Number})
        n = length(x)

        sum_of_values = sum_of_weights = χ2 = 0.0
        @avx for i=1:n
            sum_of_values += x[i] / (σ[i]*σ[i])
            sum_of_weights += 1 / (σ[i]*σ[i])
        end
        wx = sum_of_values / sum_of_weights

        @avx for i=1:n
            χ2 += (x[i] - wx) * (x[i] - wx) / (σ[i] * σ[i])
        end
        mswd = χ2 / (n-1)
        wσ = sqrt(1.0 / sum_of_weights)
        return wx, wσ, mswd
    end
    export awmean

    """
    ```julia
    (wx, wσ, mswd) = gwmean(x, σ)
    ```
    Geochronologist's weighted mean, with "MSWD correction" to uncertainty,
    i.e., wσ is increased by a factor of sqrt(mswd)
    """
    function gwmean(x, σ)
        n = length(x)

        sum_of_values = sum_of_weights = χ2 = 0.0
        @inbounds @simd for i=1:n
            sum_of_values += x[i] / (σ[i]*σ[i])
            sum_of_weights += 1 / (σ[i]*σ[i])
        end
        wx = sum_of_values / sum_of_weights

        @inbounds @simd for i=1:n
            χ2 += (x[i] - wx) * (x[i] - wx) / (σ[i] * σ[i])
        end
        mswd = χ2 / (n-1)
        wσ = sqrt(mswd / sum_of_weights)
        return wx, wσ, mswd
    end
    function gwmean(x::Array{<:Number}, σ::Array{<:Number})
        n = length(x)
        sum_of_values = sum_of_weights = χ2 = 0.0
        @avx for i=1:n
            sum_of_values += x[i] / (σ[i]*σ[i])
            sum_of_weights += 1 / (σ[i]*σ[i])
        end
        wx = sum_of_values / sum_of_weights

        @avx for i=1:n
            χ2 += (x[i] - wx) * (x[i] - wx) / (σ[i] * σ[i])
        end
        mswd = χ2 / (n-1)
        wσ = sqrt(mswd / sum_of_weights)
        return wx, wσ, mswd
    end
    export gwmean

    """
    ```julia
    MSWD(x, σ)
    ```
    Return the Mean Square of Weighted Deviates (AKA the reduced chi-squared
    statistic) of a dataset with values `x` and one-sigma uncertainties `σ`
    """
    function MSWD(x, σ)
        sum_of_values = sum_of_weights = χ2 = 0.0
        n = length(x)

        @inbounds @simd for i=1:n
            w = 1 / (σ[i]*σ[i])
            sum_of_values += w * x[i]
            sum_of_weights += w
        end
        wx = sum_of_values / sum_of_weights

        @inbounds @simd for i=1:n
            χ2 += (x[i] - wx) * (x[i] - wx) / (σ[i] * σ[i])
        end

        return χ2 / (n-1)
    end
    function MSWD(x::Array{<:Number}, σ::Array{<:Number})
        sum_of_values = sum_of_weights = χ2 = 0.0
        n = length(x)

        @avx for i=1:n
            w = 1 / (σ[i]*σ[i])
            sum_of_values += w * x[i]
            sum_of_weights += w
        end
        wx = sum_of_values / sum_of_weights

        @avx for i=1:n
            χ2 += (x[i] - wx) * (x[i] - wx) / (σ[i] * σ[i])
        end

        return χ2 / (n-1)
    end
    export MSWD

## --- End of File
