module gfm.math.quaternion;

import std.math;

import gfm.math.vector,
       gfm.math.matrix,
       funcs = gfm.math.funcs;

// hold a rotation + angle in a proper but wild space
align(1) struct Quaternion(T)
{
    public
    {
        union
        {
            Vector!(T, 4u) v;
            struct
            {
                T x, y, z, w;
            }
        }

        // construct with value
        this(U)(U x) pure nothrow if (isAssignable!U)
        {
            opAssign!U(x);
        }

        // constructs from axis + angle
        static Quaternion fromAxis(Vector!(T, 3u) axis, T angle) pure nothrow
        {
            Quaternion q = void;
            axis.normalize();
            T cos_a = cos(angle / 2);
            T sin_a = sin(angle / 2);
            q.x = sin_a * axis.x;
            q.y = sin_a * axis.y;
            q.z = sin_a * axis.z;
            q.w = cos_a;
            return q; // should be normalized
        }

        // compatible Quaternions
        ref Quaternion opAssign(U)(U u) pure nothrow if (is(typeof(U._isQuaternion)) && is(U._T : T))
        {
            v = u.v;
            return this;
        }

        // from a vector containing components
        ref Quaternion opAssign(U)(U u) pure nothrow if (is(U : Vector!(T, 4u)))
        {
            v = u;
            return this;
        }

        // normalize quaternion
        void normalize() pure nothrow
        {
            v.normalize();
        }

        // return result of normalization
        Quaternion normalized() pure const nothrow
        {
            Quaternion res = void;
            res.v = v.normalized();
            return res;
        }

        /// Inverse (aka conjugate) of quaternion
        void inverse() pure nothrow
        {
            x = -x;
            y = -y;
            z = -z;
        }

        // return result of inversion
        Quaternion inversed() pure const nothrow
        {
            Quaternion res = void;
            res.v = v;
            res.inverse();
            return res;
        }


        ref Quaternion opOpAssign(string op, U)(U q) pure nothrow
            if (is(U : Quaternion) && (op == "*"))
        {
            T nx = w * q.x + x * q.w + y * q.z - z * q.y,
              ny = w * q.y + y * q.w + z * q.x - x * q.z,
              nz = w * q.z + z * q.w + x * q.y - y * q.x,
              nw = w * q.w - x * q.x - y * q.y - z * q.z;
            x = nx;
            y = ny;
            z = nz;
            w = nw;
            return this;
        }

        ref Quaternion opOpAssign(string op, U)(U operand) pure nothrow if (isConvertible!U)
        {
            Quaternion conv = operand;
            return opOpAssign!op(conv);
        }

        Quaternion opBinary(string op, U)(U operand) pure const nothrow
            if (is(U: Quaternion) || (isConvertible!U))
        {
            Quaternion temp = this;
            return temp.opOpAssign!op(operand);
        }

        // compare two Quaternions
        bool opEquals(U)(U other) pure const if (is(U : Quaternion))
        {
            return v == other.v;
        }

        // compare Quaternion and other types
        bool opEquals(U)(U other) pure const nothrow if (isConvertible!U)
        {
            Quaternion conv = other;
            return opEquals(conv);
        }

        // convert to 3x3 rotation matrix
        // TODO: check out why we can't do is(Unqual!U == mat3!T)
        U opCast(U)() pure const nothrow if (is(typeof(U._isMatrix))
                                          && is(U._T : _T)
                                          && (U._R == 3) && (U._C == 3))
        {
            // do not assume that quaternion is normalized
            T norm = x*x + y*y + z*z + w*w;
            T s = (norm > 0) ? 2 / norm : 0;

            T xx = x * x * s, xy = x * y * s, xz = x * z * s, xw = x * w * s,
                              yy = y * y * s, yz = y * z * s, yw = y * w * s,
                                              zz = z * z * s, zw = z * w * s;
            return mat3!(U._T)
            (
                1 - (yy + zz)   ,   (xy - zw)    ,   (xz + yw)    ,
                  (xy + zw)     , 1 - (xx + zz)  ,   (yz - xw)    ,
                  (xz - yw)     ,   (yz + xw)    , 1 - (xx + yy)
            );
        }

        // convert to 4x4 rotation matrix
        // TODO: check out why we can't do is(Unqual!U == mat4!T)
        U opCast(U)() pure const nothrow if (is(typeof(U._isMatrix))
                                          && is(U._T : _T)
                                          && (U._R == 4) && (U._C == 4))
        {
            auto m3 = cast(mat3!(U._T))(this);
            return cast(U)(m3);
        }

        // Workaround Vector not being constructable through CTFE
        static Quaternion IDENTITY() pure nothrow @property
        {
            Quaternion q;
            q.x = q.y = q.z = 0;
            q.w = 1;
            return q;
        }
    }

    private
    {
        alias T _T;
        enum _isQuaternion = true;

        template isAssignable(T)
        {
            enum bool isAssignable =
                is(typeof(
                {
                    T x;
                    Quaternion v = x;
                }()));
        }

        // define types that can be converted to Quaternion, but are not Quaternion
        template isConvertible(T)
        {
            enum bool isConvertible = (!is(T : Quaternion)) && isAssignable!T;
        }
    }
}

alias Quaternion!float quaternionf;
alias Quaternion!double quaterniond;

unittest
{
    quaternionf a = quaternionf.fromAxis(vec3f(1, 0, 0), 1);
    quaternionf b = quaternionf.fromAxis(vec3f(0, 1, 0), 0);

    a = a * b;
}

/// Return Nlerp of quaternions
/// See: http://keithmaggio.wordpress.com/2011/02/15/math-magician-lerp-slerp-and-nlerp/
Quaternion!T Nlerp(T)(Quaternion!T a, Quaternion!T b, float t) pure nothrow
{
    Quaternion res = void;
    res.v = lerp(a.v, b.v, t);
    res.v.normalize();
    return res;
}