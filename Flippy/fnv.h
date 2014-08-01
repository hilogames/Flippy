/* $Id$ */
/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <bonelli@antifork.org> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return. Nicola Bonelli 
 * ----------------------------------------------------------------------------
 */

/*
 * Fowler/Noll/Vo hash
 *
 * The basis of this hash algorithm was taken from an idea sent
 * as reviewer comments to the IEEE POSIX P1003.2 committee by:
 *
 *      Phong Vo (http://www.research.att.com/info/kpv/)
 *      Glenn Fowler (http://www.research.att.com/~gsf/)
 *
 * In a subsequent ballot round:
 *
 *      Landon Curt Noll (http://www.isthe.com/chongo/)
 *
 * improved on their algorithm.  Some people tried this hash
 * and found that it worked rather well.  In an EMail message
 * to Landon, they named it the ``Fowler/Noll/Vo'' or FNV hash.
 *
 * FNV hashes are designed to be fast while maintaining a low
 * collision rate. The FNV speed allows one to quickly hash lots
 * of data while maintaining a reasonable collision rate.  See:
 *
 *      http://www.isthe.com/chongo/tech/comp/fnv/index.html
 *
 * for more details as well as other forms of the FNV hash.
 *
 ***
 *
 * Please do not copyright this code.  This code is in the public domain.
 *
 * LANDON CURT NOLL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL LANDON CURT NOLL BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
 * USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
 * OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 *
 * By:
 *  chongo <Landon Curt Noll> /\oo/\
 *      http://www.isthe.com/chongo/
 *
 * Share and Enjoy! :-)
 */

#ifndef FNV_HH
#define FNV_HH

#include <stdlib.h>
#include <stdint.h>
#include <sys/uio.h>

#include <string>

namespace hash {

    template <int N> class fnv;

    template <>
    class fnv<32>
    {
        static const uint32_t FNV_32_PRIME = 0x01000193UL;
        uint32_t m_offset;

    public:
        static const uint32_t INIT  = 0x811c9dc5UL;

        fnv(const uint32_t init = INIT)
        : m_offset(init) 
        {}

        void offset(uint32_t init)
        { m_offset = init; }

        uint32_t operator()(const std::string &_buf)
        {
            return operator()(_buf.c_str(), _buf.length());
        }

        uint32_t operator()(const char *_buf, size_t _len)
        {
            const unsigned char *bp = reinterpret_cast<const unsigned char *>(_buf); /* start of buffer */
            const unsigned char *be = bp + _len;                                     /* beyond end of buffer */

            uint32_t hval = m_offset;

            /*
             * FNV-1a hash each octet in the buffer
             */
            while (bp < be) {

                /* xor the bottom with the current octet */
                hval ^= (uint32_t)*bp++;

                /* multiply by the 32 bit FNV magic prime mod 2^32 */

#if defined(NO_FNV_GCC_OPTIMIZATION)
                hval *= FNV_32_PRIME;
#else
                hval += (hval<<1) + (hval<<4) + (hval<<7) + (hval<<8) + (hval<<24);
#endif
            }

            /* return our new hash value */
            return m_offset = hval;
        }

        // iovec implementation...
        //

        uint32_t 
        operator()(const struct iovec * _vector, size_t _count)
        {
            unsigned char *bp;  /* start of block */
            unsigned char *be;  /* beyond end of buffer */

            uint32_t hval = m_offset;

            for (unsigned int lcount = 0; lcount < _count; lcount++) {
                bp = (unsigned char *)_vector[lcount].iov_base;
                be = (unsigned char *)_vector[lcount].iov_base + _vector[lcount].iov_len;

                /*
                 * FNV-1a hash each octet in the buffer
                 */
                while (bp < be) {
                    /* xor the bottom with the current octet */
                    hval ^= (uint32_t) * bp++;

                    /* multiply by the 32 bit FNV magic prime mod 2^32 */
#if defined(NO_FNV_GCC_OPTIMIZATION)
                    hval *= FNV_32_PRIME;
#else
                    hval += (hval << 1) + (hval << 4) + (hval << 7) + (hval << 8) + (hval << 24);
#endif
                }

            }

            /* return our new hash value */
            return m_offset = hval;
        }

    };

    template <>
    class fnv<64>
    {
        static const uint64_t FNV_64_PRIME = 0x100000001b3ULL;
        uint64_t m_offset;

    public:
        static const uint64_t INIT  = 0xcbf29ce484222325ULL;

        fnv(const uint64_t init = INIT)
        : m_offset(init) 
        {}

        void offset(uint64_t init)
        { m_offset = init; }

        uint64_t operator()(const std::string &_buf)
        {
            return operator()(_buf.c_str(), _buf.length());
        }

        uint64_t operator()(const char *_buf, size_t _len)
        {
            const unsigned char *bp = reinterpret_cast<const unsigned char *>(_buf); /* start of buffer */
            const unsigned char *be = bp + _len;                                     /* beyond end of buffer */

            uint64_t hval = m_offset;

            /*
             * FNV-1a hash each octet of the buffer
             */
            while (bp < be) {

                /* xor the bottom with the current octet */
                hval ^= (uint64_t)*bp++;

                /* multiply by the 64 bit FNV magic prime mod 2^64 */

#if defined(NO_FNV_GCC_OPTIMIZATION)
                hval *= FNV_64_PRIME;
#else
                hval += (hval << 1) + (hval << 4) + (hval << 5) +
                (hval << 7) + (hval << 8) + (hval << 40);
#endif
            }

            return m_offset = hval;
        }

        uint64_t 
        operator()(const struct iovec * _vector, size_t _count)
        {
            unsigned char *bp;  /* start of buffer */
            unsigned char *be;  /* beyond end of buffer */

            uint64_t hval = m_offset;

            for (unsigned int lcount = 0; lcount < _count; lcount++) {

                bp = (unsigned char *)_vector[lcount].iov_base;
                be = (unsigned char *)_vector[lcount].iov_base + _vector[lcount].iov_len;

                /*
                 * FNV-1a hash each octet of the buffer
                 */
                while (bp < be) {

                    /* xor the bottom with the current octet */
                    hval ^= (uint64_t) * bp++;

                    /* multiply by the 64 bit FNV magic prime mod 2^64 */
#if defined(NO_FNV_GCC_OPTIMIZATION)
                    hval *= FNV_64_PRIME;
#else
                    hval += (hval << 1) + (hval << 4) + (hval << 5) +
                    (hval << 7) + (hval << 8) + (hval << 40);
#endif
                }
            }

            /* return our new hash value */
            return m_offset = hval;
        }

    };

}

#endif /* FNV_HH */
