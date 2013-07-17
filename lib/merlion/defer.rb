require 'fiber'

class Merlion
	# A wrapper for EM.defer using Fibers
	module Defer
		# Defers jobs using EM.defer, and only resumes the Fiber once all jobs have completed
		def defer(&blk)
			@f = Fiber.current
			@_defer ||= 0
			@_defer += 1
			cb = Proc.new { job_completed }
			EM.defer(blk, cb)
		end

		def job_completed
			@_defer -= 1
			@f.resume if @_defer == 0
		end

		def wait_on_jobs
			return Fiber.yield
		end
	end
end
