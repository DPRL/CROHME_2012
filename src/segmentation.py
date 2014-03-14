##    DPRL CROHME 2012
##    Copyright (c) 2012-2014 Lei Hu, David Stalnaker, Richard Zanibbi
##
##    This file is part of DPRL CROHME 2012.
##
##    DPRL CROHME 2012 is free software: 
##    you can redistribute it and/or modify it under the terms of the GNU 
##    General Public License as published by the Free Software Foundation, 
##    either version 3 of the License, or (at your option) any later version.
##
##    DPRL CROHME 2012 is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with DPRL CROHME 2012.  
##    If not, see <http://www.gnu.org/licenses/>.
##
##    Contact:
##        - Lei Hu: lei.hu@rit.edu
##        - David Stalnaker: david.stalnaker@gmail.com
##        - Richard Zanibbi: rlaz@cs.rit.edu 

import xml.dom.minidom as minidom
import math
import sys
import os
import os.path
import itertools
import collections
import codecs
from copy import deepcopy

import numpy as np

CLOSEST_DIST_THRESHOLD = 0.27
T_ALWAYS = 0.2
T_NEVER = 1.2

WIDE_THRESHOLD = 2.5
NARROW_THRESHOLD = 0.3

CLASSIFY_URL = 'http://129.21.34.109:1503'
CLASSES = {"0": "0","1": "1","2": "2","3": "3","4": "4","5": "5","6": "6","7": "7","8": "8","9": "9","_plus": "+","_dash": "-","_equal": "\\eq","geq": "\\geq","lt": "\\lt","neq": "\\neq","leq": "\\leq","int": "\\int","times": "\\times","sum": "\\sum","sqrt": "\\sqrt","lim": "\\lim","log": "\\log","ldots": "\\ldots","rightarrow": "\\rightarrow","sin": "\\sin","tan": "\\tan","cos": "\\cos","pm": "\\pm","div": "\\div","_excl": "!","left_bracket": "[","right_bracket": "]","_lparen": "(","_rparen": ")","a_lower": "a","b_lower": "b","c_lower": "c","d_lower": "d","e_lower": "e","i_lower": "i","j_lower": "j","k_lower": "k","n_lower": "n","x_lower": "x","y_lower": "y","z_lower": "z","A_upper": "A","B_upper": "B","C_upper": "C","F_upper": "F",		"X_upper": "X","alpha": "\\alpha","beta": "\\beta","gamma": "\\gamma","theta": "\\theta","pi": "\\pi","phi": "\\phi"}

def zipwith(fun, *args):
	return map(lambda x: fun(*x), zip(*args))
	
def distance(point1, point2):
	box = zipwith(lambda x,y: abs(x - y), point1, point2)
	return math.sqrt(sum(map(lambda x: x**2, box)))

class Equation(object):
	def __init__(self):
		super(Equation, self).__init__()
		self.strokes = {}
		self.segments_truth = SegmentSet()
		self.segments = SegmentSet()
		
	@classmethod
	def from_inkml(cls, filename):
		dom = minidom.parse(filename)
		self = cls()
		self.dom = dom

		for node in self.dom.getElementsByTagName('trace'):
			trace_id = int(node.getAttribute('id'))
			points_string = node.firstChild.data.split(',')
			points = []
			for p in points_string:
				points.append(tuple(map(float, p.split())))
			self.strokes[trace_id] = Stroke(trace_id, points)

		for node in self.dom.getElementsByTagName('traceGroup'):
			group = []
			symbol = node.getElementsByTagName('annotation')[0].firstChild.data.strip()
			if symbol == "Segmentation":
				continue
			for stroke in node.getElementsByTagName('traceView'):
				group.append(int(stroke.getAttribute('traceDataRef')))

			self.segments_truth.add(Segment(group, symbol))
		self.segments = SegmentSet.init_unconnected_strokes([s.id for s in self.strokes.values()])

		return self
		
	def output_inkml(self, filename):
		math = self.dom.getElementsByTagName('math')[0]
		for c in list(math.childNodes):
			math.removeChild(c)
			c.unlink()
		mrow = self.dom.createElement('mrow')
		math.appendChild(mrow)
		group = self.dom.getElementsByTagName('traceGroup')[0]
		for c in list(group.childNodes):
			if c.nodeName == 'annotation':
				continue
			group.removeChild(c)
			c.unlink()
		for i, seg in enumerate(sorted(self.segments, key=lambda x: min(x.strokes))):
			mi = self.dom.createElement('mi')
			mi.setAttribute('xml:id', 'x_%d' % i)
			mi.appendChild(self.dom.createTextNode('x'))
			mrow.appendChild(mi)
			
			tgid = int(group.getAttribute('xml:id')) + 1
			tg = self.dom.createElement('traceGroup')
			tg.setAttribute('xml:id', str(tgid + i))
			an = self.dom.createElement('annotation')
			an.setAttribute('type', 'truth')
			an.appendChild(self.dom.createTextNode('x'))
			tg.appendChild(an)
			for stroke in seg.strokes:
				tv = self.dom.createElement('traceView')
				tv.setAttribute('traceDataRef', str(stroke))
				tg.appendChild(tv)
			ml = self.dom.createElement('annotationXML')
			ml.setAttribute('href', 'x_%d' % i)
			tg.appendChild(ml)
			group.appendChild(tg)
			
			
		with codecs.open(filename,'w','utf-8') as f:
			self.dom.writexml(f, encoding='utf-8')

	def contains_true_segmentation(self):
		return self.segments_truth in self.segments.combinations()

	def test_fuzzy_segments(self):
		all_segs = set()
		for fs in self.segments:
			c = fs.combinations()
			for s in c:
				all_segs.update(s)

		correct = len(all_segs.intersection(self.segments_truth))
		return (correct, len(all_segs), len(self.segments_truth))
		
	def test_segments(self):		
		correct = len(self.segments.intersection(self.segments_truth))			
		return (correct, len(self.segments), len(self.segments_truth))
		
	def test_segments_by_symbol(self):
		ret = {}
		for s in self.segments_truth:
			correct = 1 if s in self.segments else 0
			if s.symbol in ret:
				ret[s.symbol] = tuple(zipwith(lambda x,y: x + y, ret[s.symbol], (correct, 1)))
			else:
				ret[s.symbol] = (correct, 1)
		return ret
		
	def segment_for_stroke(self, i):
		if not hasattr(self, '_segments_by_strokes'):
			self._segments_by_strokes = {}
			for s in self.segments:
				for st in s.strokes:
					self._segments_by_strokes[st] = s
		return self._segments_by_strokes[i]
		
	def segment_truth_for_stroke(self, i):
		if not hasattr(self, '_segments_truth_by_strokes'):
			self._segments_truth_by_strokes = {}
			for s in self.segments_truth:
				for st in s.strokes:
					self._segments_truth_by_strokes[st] = s
		try:
			return self._segments_truth_by_strokes[i]
		except:
			return Segment(['x'])
			
	def missed_symbol(self, symbol):
		for s in self.segments_truth:
			if s.symbol == symbol and s not in self.segments:
				return True
		return False
	
	def test_classification(self):
		correct = 0
		for st in self.strokes.keys():
			if self.segment_for_stroke(st).symbol == self.segment_truth_for_stroke(st).symbol:
				correct += 1
		return (correct, len(self.strokes))
		
	def classify(self):
		import requests
		for s in self.segments:
			req = [CLASSIFY_URL]
			req.append('/?segmentList=<SegmentList>')
			for st in s.strokes:
				req.append('<Segment type="pen_stroke" instanceID="%d" scale="1,1" translation="0,0" points="%s"/>'
					% (st, '|'.join(map(lambda x: str(x[0]) + ',' + str(x[1]), self.strokes[st].points))))
			req.append('</SegmentList>&segment=false')
			r = requests.get(''.join(req))
			dom = minidom.parseString(r.text)
			try:
				sym = dom.getElementsByTagName('Result')[0].getAttribute('symbol')
				s.symbol = CLASSES[sym]
			except IndexError:
				s.symbol = 'x'
			except KeyError:
				s.symbol = sym
		
		
	def segment(self):
		wide_strokes = self.get_wide_strokes()
		self.merge_dots()
		#self.merge_touching()
		
		pairs = zip(self.strokes.values(), self.strokes.values()[1:])
		for s1, s2 in pairs:
			if s1 in wide_strokes or s2 in wide_strokes:
				continue
			if s1.closest_distance(s2) / s1.average_diag(s2) < CLOSEST_DIST_THRESHOLD:
				self.segments.merge_strokes(s1.id, s2.id)

	def segment_fuzzy(self, test_intersection=True):
		if not isinstance(self.segments, FuzzySegmentSet):
			self.segments = FuzzySegmentSet.from_segment_set(self.segments)
		wide_strokes = self.get_wide_strokes()
		self.merge_dots()
		strokes = sorted(self.strokes.values(), key=lambda x: x.id)
		for s in wide_strokes:
			strokes.remove(s)
		for s in self.get_dots(NARROW_THRESHOLD):
			strokes.remove(s)
			
		if test_intersection:
			self.merge_touching()
		
		pairs = zip(strokes, strokes[1:])
		for s1, s2 in pairs:
			d = s1.closest_distance(s2) / s1.average_diag(s2)
			if d < T_ALWAYS:
				self.segments.merge_strokes(s1.id, s2.id, 1)
			elif d < T_NEVER:
				self.segments.merge_strokes(s1.id, s2.id, self.score(d))
		self.segments.limit_size()

	def score(self, dist):
		if dist < T_ALWAYS:
			return 1.0
		if dist < CLOSEST_DIST_THRESHOLD:
			return (-0.5) * (dist - T_ALWAYS) / (CLOSEST_DIST_THRESHOLD - T_ALWAYS) + 1
		if dist < T_NEVER:
			return (-0.5) * (dist - CLOSEST_DIST_THRESHOLD) / (T_NEVER - CLOSEST_DIST_THRESHOLD) + 0.5
		return 0.0

						
	def merge_touching(self):
		for s1, s2 in itertools.combinations(self.strokes.values(), 2):
			if s1.bb_intersects(s2):
				if s1.intersects(s2):
					self.segments.merge_strokes(s1.id, s2.id)
			
	def find_closest_stroke(self, stroke):
		d = 9001
		closest = -1
		for id, s in self.strokes.items():
			if s != stroke:
				if d > closest_distance(s, stroke):
					closest = id
					d = closest_distance(s, stroke)
		return closest
		
	def avg_extents(self):
		if not hasattr(self, '_avg_extents'):
			widths = []
			heights = []
			diags = []
			for s in self.strokes.values():
				mins, maxs = s.extents
				widths.append(maxs[0] - mins[0])
				heights.append(maxs[1] - mins[1])
				diags.append(s.half_diag)	
			avg_width = median(widths)
			avg_height = median(heights)
			avg_diag = median(diags)
			self._avg_extents = avg_width, avg_height, avg_diag
		return self._avg_extents
		
	def get_wide_strokes(self):
		avg_width = self.avg_extents()[0]
		wide_strokes = set()
		for s in self.strokes.values():
			if s.width > WIDE_THRESHOLD * avg_width:
				wide_strokes.add(s)
		return wide_strokes
		
	def get_dots(self, thresh):
		avg_width, avg_height, avg_diag = self.avg_extents()
		dots = set()
		for s in self.strokes.values():
			if s.half_diag < thresh * avg_diag:
				dots.add(s)
		return dots
		
	def merge_dots(self):
		avg_width, avg_heigh, avg_diag  = self.avg_extents()
		for s in self.get_dots(NARROW_THRESHOLD):
			neighbors = []
			if s.id - 1 in self.strokes:
				neighbors.append(self.strokes[s.id - 1])
			if s.id + 1 in self.strokes:
				neighbors.append(self.strokes[s.id + 1])
			closest = reduce(lambda x,y: x if x.closest_distance(s) < y.closest_distance(s) else y, neighbors)
			self.segments.merge_strokes(s.id, closest.id)
				
def median(l):
	ls = sorted(l)
	n = len(l)
	if n % 2 == 1:
		return ls[(n - 1) / 2]
	else:
		low = ls[(n / 2) - 1]
		high = ls[n / 2]
		return float(low + high) / 2
		

class SegmentSet(set):
	def __init__(self, *args, **kwargs):
		super(SegmentSet, self).__init__(*args, **kwargs)
		self.prob = 1.0

	@classmethod
	def init_unconnected_strokes(cls, strokes):
		return cls([Segment([s]) for s in strokes])

	def __repr__(self):
		segs = []
		for s in self:
			segs.append(sorted(s.strokes))
		segs.sort(key=lambda x:x[0])
		return '%s : %.6f' % ('; '.join([', '.join(map(str, s)) for s in segs]), self.prob)

	def biggest_segment(self):
		return max([len(s.strokes) for s in self])

	def merge_strokes(self, first, second):
		seg1 = None
		seg2 = None
		for s in self:
			if first in s:
				seg1 = s
			if second in s:
				seg2 = s
		if seg1 != seg2:
			self.remove(seg1)
			self.remove(seg2)
			self.add(seg1.union(seg2))

class FuzzySegmentSet(SegmentSet):
	@classmethod
	def init_unconnected_strokes(cls, strokes):
		return cls([FuzzySegment([s]) for s in strokes])

	@classmethod
	def from_segment_set(cls, sset):
		return cls([FuzzySegment(s.strokes) for s in sset])

	def merge_strokes(self, first, second, prob=1.0):
		seg1 = None
		seg2 = None
		for s in self:
			if first in s:
				seg1 = s
			if second in s:
				seg2 = s
		if seg1 != seg2:
			self.remove(seg1)
			self.remove(seg2)
			self.add(seg1.union(seg2, {(first, second): prob}))

	def combinations(self):
		sets = [SegmentSet()]
		for fs in self:
			newsets = []
			for s in sets:
				for c in fs.combinations():
					new = deepcopy(s)
					new.update(c)
					new.prob *= c.prob
					newsets.append(new)
			sets = newsets
		return sets

	def best_combination(self):
		s = SegmentSet()
		for fs in self:
			best = fs.best_combination()
			s.update(best)
			s.prob *= best.prob
		return s

	def num_combs(self):
		p = 1
		for fs in self:
			p *= len(fs.combinations())
		return p

	def limit_size(self):
		while True:
			biggest = list(self)[0]
			for s in self:
				if len(s.strokes) > len(biggest.strokes):
					biggest = s
			if len(biggest.strokes) <= 10:
				break
			newsegs = biggest.split_weakest()
			self.remove(biggest)
			self.update(newsegs)
			
				

class Segment(object):
	def __init__(self, strokes, symbol='x'):
		self.strokes = frozenset(strokes)
		self.symbol = symbol
		
	def __hash__(self):
		return self.strokes.__hash__()
		
	def __eq__(self, other):
		return self.strokes == other.strokes
		
	def __ne__(self, other):
		return not self == other
		
	def __contains__(self, item):
		return item in self.strokes
		
	def __repr__(self):
		return 'Segment(%s, \'%s\')' % (repr(self.strokes), self.symbol)
		
	def union(self, other):
		return Segment(self.strokes.union(other.strokes), self.symbol)
		
	def intersection(self, other):
		return Segment(self.strokes.intersection(other.strokes), self.symbol)

class FuzzySegment(Segment):
	def __init__(self, strokes, transitions={}, symbol='x'):
		super(FuzzySegment, self).__init__(strokes, symbol)
		self.transitions = transitions

	def union(self, other, newtransition={}):
		strokes = self.strokes.union(other.strokes)
		transitions = dict(self.transitions.items() + other.transitions.items() + newtransition.items())
		return FuzzySegment(strokes, transitions)

	def combinations(self, max_group=4):
		segments = [SegmentSet.init_unconnected_strokes(self.strokes)]
		for (src, dst), p in sorted(self.transitions.items(), key=lambda x: x[1], reverse=True):
			together = []
			if p > 0.0:
				for s in segments:
					s2 = deepcopy(s)
					s2.merge_strokes(src, dst)
					s2.prob *= p
					if s2.biggest_segment() <= max_group:
						together.append(s2)
					elif len(segments) == 1 and p >= 1:
						together.append(s2)
			if p < 1.0:
				for s in segments:
					s.prob *= (1.0 - p)
			else:
				segments = []
			segments.extend(together)
		return segments

	def best_combination(self):
		s = SegmentSet.init_unconnected_strokes(self.strokes)
		for (src, dst), p in sorted(self.transitions.items(), key=lambda x: x[1], reverse=True):
			if p > 0.5:
				s.merge_strokes(src, dst)
				s.prob *= p
			else:
				s.prob *= (1.0 - p)
		return s

	def split_weakest(self):
		newset = FuzzySegmentSet.init_unconnected_strokes(self.strokes)
		transitions = sorted(self.transitions.items(), key=lambda x: x[1], reverse=True)[:-1]
		for (src, dst), p in transitions:
			newset.merge_strokes(src, dst, p)
		return newset
		
class Stroke(object):
	def __init__(self, id, points):
		self.id = id
		self.points = points
	
	def __eq__(self, other):
		return self.id == other.id and self.points == other.points
		
	def __ne__(self, other):
		return not self == other

	def __hash__(self):
		return hash((id, str(self.points)))

	def __repr__(self):
		return 'Stroke(id=%d)' % self.id
		
	@property
	def extents(self):
		if not (hasattr(self, '_mins') and hasattr(self, '_maxs')):
			mins = list(self.points[0])
			maxs = list(self.points[0])
			
			for point in self.points:
				mins = zipwith(min, mins, point)
				maxs = zipwith(max, maxs, point)
			self._mins, self._maxs = tuple(mins), tuple(maxs)
		return self._mins, self._maxs
		
	@property
	def center(self):
		mins, maxs = self.extents
		box = zipwith(lambda x,y: abs(x - y), mins, maxs)
		return zipwith(lambda m,b: m + (float(b) / 2), mins, box)
		
	@property
	def half_diag(self):
		return distance(*self.extents) / 2
		
	@property
	def width(self):
		mins, maxs = self.extents
		return maxs[0] - mins[0]
		
	@property
	def height(self):
		mins, maxs = self.extents
		return maxs[1] - mins[1]
		
	def average_diag(self, other):
		avg_diag = (self.half_diag + other.half_diag) / 2
		if avg_diag == 0:
			avg_diag = 0.01
		return avg_diag

	def center_distance(self, other):
		return distance(self.center, other.center)

	def closest_distance(self, other):
		ret = distance(self.points[0], other.points[0])
		for x in self.points:
			for y in other.points:
				ret = min(ret, distance(x, y))
		return ret
		
	def bb_intersects(self, other):
		mins, maxs = self.extents
		o_mins, o_maxs = other.extents
		return (mins[0] < o_maxs[0]) and (maxs[0] > o_mins[0]) and (mins[1] < o_maxs[1]) and (maxs[1] > o_mins[1])
		
	def intersects(self, other):
		for s1, s2 in zip(self.points, self.points[1:]):
			for o1, o2 in zip(other.points, other.points[1:]):
				if s1 == o1 or s1 == o2 or s2 == o1 or s2 == o2:
					return True
				v1 = np.cross(vect(s1, o1), vect(s1, s2))
				v2 = np.cross(vect(s1, o2), vect(s1, s2))
				if v1[2] * v2[2] < 0:
					w1 = np.cross(vect(o1, s1), vect(o1, o2))
					w2 = np.cross(vect(o1, s2), vect(o1, o2))
					if w1[2] * w2[2] < 0:
						return True
		return False

def vect(a, b):
	return np.array([b[0] - a[0], b[1] - a[1], 0])
	
	
def count_nonadjacent_strokes(path):
	count = 0
	for filename in os.listdir(path):
		if os.path.splitext(filename)[1] == '.inkml':
			print(filename)
			eq = Equation.from_inkml(os.path.join(path, filename))
			for s in eq.segments_truth:
				m = min(s.strokes)
				l = len(s.strokes)
				for i in range(m + 1, m + l):
					if i not in s:
						count += 1
						print(s)
	print('%d segments contain non-adjacent strokes' % count)
	
def split_stats(stats, mapping, partition, filtering=None, filter_outliers=True):
	if filter_outliers:
		stats = filter(lambda x: not x.is_wide and not x.is_dot, stats)
	if filtering:
		stats = filter(filtering, stats)
	fst = map(mapping, filter(partition, stats))
	snd = map(mapping, filter(lambda x: not partition(x), stats))
	return fst, snd
	
def show_hist(data):
	import matplotlib.pyplot as plt
	if not isinstance(data[0], collections.Iterable):
		data = [data]
	for d in data:
		plt.hist(d, bins=500 / 3, range=(0,1), alpha=0.7)
	plt.show()

def test_dots(path):
	dot_symbols = ['i', '\\sin', '!', '\\lim', '\\div', 'j', '\\ldots']
	files = [f for f in os.listdir(path) if os.path.splitext(f)[1] == '.inkml']
	for t in [0.25, 0.26, 0.27, 0.28, 0.29, 0.30, 0.31, 0.32, 0.33, 0.34, 0.35]:
		num_correct, num_total, num_truth = 0, 0, 0
		for i, filename in enumerate(files):
			eq = Equation.from_inkml(os.path.join(path, filename))
			dots = eq.get_dots(t)
			symbs = map(lambda x: eq.segment_truth_for_stroke(x.id).symbol, dots)
			num_correct += len(filter(lambda x: x in dot_symbols, symbs))
			num_total += len(symbs)
			num_truth += len(filter(lambda x: x.symbol in dot_symbols, eq.segments_truth))
		print('\nthreshold: %.2f' % (t))
		print('precision:\t%f\t(%d/%d)' % (float(num_correct) / num_total, num_correct, num_total))
		print('recall:\t\t%f\t(%d/%d)' % (float(num_correct) / num_truth, num_correct, num_truth))
	
	
def get_distance_stats(path):
	Stat = collections.namedtuple('Stat', ['together', 'closest_distance', 'center_distance', 'is_wide', 'is_dot', 'symbols'])
	stats = []
	for filename in os.listdir(path):
		if os.path.splitext(filename)[1] == '.inkml':
			print(filename)
			eq = Equation.from_inkml(os.path.join(path, filename))
			
			wides = eq.get_wide_strokes()
			dots = eq.get_dots()
			
			pairs = zip(eq.strokes.values(), eq.strokes.values()[1:])
			for s1, s2 in pairs:
				try:
					seg1 = eq.segment_truth_for_stroke(s1.id)
					seg2 = eq.segment_truth_for_stroke(s2.id)
					av_diag = s1.average_diag(s2)
					closest_dist = s1.closest_distance(s2) / av_diag
					center_dist = s1.center_distance(s2) / av_diag
					is_wide = s1 in wides or s2 in wides
					is_dot = s1 in dots or s2 in dots
					symbols = (seg1.symbol, seg2.symbol)
					stats.append(Stat(seg1 == seg2, closest_dist, center_dist, is_wide, is_dot, symbols))
					
				except KeyError:
					pass
	if __name__ == '__main__':
		import matplotlib.pyplot as plt
		plt.hist([x.closest_distance for x in stats if x.together and x.closest_distance < 5], alpha=0.7, bins=500)
		plt.hist([x.closest_distance for x in stats if not x.together and x.closest_distance < 5], alpha=0.7, bins=500)
		plt.show()
		
	return stats
	
def test_segmentations(path, inkml_path=None, miss_char=None, classify=False):
	equations_correct = 0
	total_correct, total_segments, total_truth = 0, 0, 0
	correct_class, num_strokes = 0, 0
	by_symbol = {}
	files = [f for f in os.listdir(path) if os.path.splitext(f)[1] == '.inkml']
	for i, filename in enumerate(files):
		print('%s (%d/%d)' % (filename, i + 1, len(files)))
		eq = Equation.from_inkml(os.path.join(path, filename))
		eq.segment()
		if classify:
			eq.classify()
			c, s = eq.test_classification()
			correct_class += c
			num_strokes += s
		correct, num_segments, num_truth = eq.test_segments()
		total_correct += correct
		total_segments += num_segments
		total_truth += num_truth
		if eq.segments == eq.segments_truth:
			equations_correct += 1
		else:
			if inkml_path and miss_char and eq.missed_symbol(miss_char):
				eq.output_inkml(os.path.join(inkml_path, filename))
		
		s = eq.test_segments_by_symbol()
		for k, v in s.items():
			if k in by_symbol:
				by_symbol[k] = tuple(zipwith(lambda x,y: x + y, by_symbol[k], v))
			else:
				by_symbol[k] = v
	
	print('recall by symbol:')
	from prettytable import PrettyTable
	table = PrettyTable(['symbol', 'rec. rate', 'fraction correct', 'num missed'])
	for k,v in sorted(by_symbol.items(), key=lambda x: x[1][1] - x[1][0], reverse=True):
		correct, total = v
		table.add_row([k, '%0.4f' % (float(correct) / total), '%d/%d' % (correct, total), total - correct])
	print(table)
	print('')
	print('precision:\t%f\t(%d/%d)' % (float(total_correct) / total_segments, total_correct, total_segments))
	print('recall:\t\t%f\t(%d/%d)' % (float(total_correct) / total_truth, total_correct, total_truth))
	print('')
	print('Full correct equations: %d/%d' % (equations_correct, len(files)))
	print('')
	if classify:
		print('correct classification for strokes\t%f\t(%d/%d)' % (float(correct_class) / num_strokes, correct_class, num_strokes))
	
def test_classifications(path):
	return test_segmentations(path, classify=True)
	
def get_segmentations(input_path, output_path):
	files = [f for f in os.listdir(input_path) if os.path.splitext(f)[1] == '.inkml']
	for fullname in files:
		filename, extension = os.path.splitext(fullname)
		print(fullname)
		eq = Equation.from_inkml(os.path.join(input_path, fullname))
		eq.segment()
		
		with open(os.path.join(output_path, filename + '.seg'), 'w') as output:
			for seg in eq.segments:
				output.write(','.join([str(s) for s in seg.strokes]))
				output.write('\n')

def test_segmentations_fuzzy(input_path):
	equations_correct = 0
	total_correct, total_segments, total_truth = 0, 0, 0
	greedy_equations_correct = 0
	greedy_correct, greedy_total = 0, 0
	files = [f for f in os.listdir(input_path) if os.path.splitext(f)[1] == '.inkml']
	for i, fullname in enumerate(files):
		print('%s (%d/%d)' % (fullname, i + 1, len(files)))
		filename, extension = os.path.splitext(fullname)
		eq = Equation.from_inkml(os.path.join(input_path, fullname))
		eq.segment_fuzzy()
		correct, num_segments, num_truth = eq.test_fuzzy_segments()
		total_correct += correct
		total_segments += num_segments
		total_truth += num_truth
		if correct == num_truth:
			equations_correct += 1

		best = eq.segments.best_combination()
		best_correct = len(best.intersection(eq.segments_truth))
		greedy_correct += best_correct
		greedy_total += len(best)

		if best_correct == num_truth:
			greedy_equations_correct += 1

	print('\nFor full set of segmentations:')
	print('precision:\t%f\t(%d/%d)' % (float(total_correct) / total_segments, total_correct, total_segments))
	print('recall:\t\t%f\t(%d/%d)' % (float(total_correct) / total_truth, total_correct, total_truth))
	print('full correct equations: %d/%d' % (equations_correct, len(files)))

	print('\nFor greedy selection of one segmentation:')
	print('precision:\t%f\t(%d/%d)' % (float(greedy_correct) / greedy_total, greedy_correct, greedy_total))
	print('recall:\t\t%f\t(%d/%d)' % (float(greedy_correct) / total_truth, greedy_correct, total_truth))
	print('full correct equations: %d/%d' % (greedy_equations_correct, len(files)))

def argmax(items, key):
	best, best_score = None, None
	for i in items:
		s = key(i)
		if best_score is None or s > best_score:
			best = i
			best_score = s
	return best
	

def get_segmentations_fuzzy(input_path, output_path, output_ground_truth=False):
	if os.path.splitext(input_path)[1] == '.inkml':
		input_path, f = os.path.split(input_path)
		files = [f]
	else:
		files = [f for f in os.listdir(input_path) if os.path.splitext(f)[1] == '.inkml']
	for i, fullname in enumerate(files):
		print('%s (%d/%d)' % (fullname, i + 1, len(files)))
		filename, extension = os.path.splitext(fullname)
		eq = Equation.from_inkml(os.path.join(input_path, fullname))
		eq.segment_fuzzy()

		dirname = os.path.join(output_path, filename)
		if not os.path.exists(dirname):
			os.makedirs(dirname)

		for stroke in eq.strokes.values():
			with open(os.path.join(dirname, str(stroke.id) + '.str'), 'w') as sfile:
				sfile.write(str(len(stroke.points)) + '\n')
				for p in stroke.points:
					sfile.write('%f %f\n' % p)
		
		with open(os.path.join(dirname, filename + '.seg'), 'w') as output:
			
			segs = list(eq.segments)
			segs.sort(key=lambda x:sorted(x.strokes)[0])

			for seg in segs:
				output.write(','.join([str(s) for s in sorted(seg.strokes)]))
				output.write('\n')
				combs = sorted(seg.combinations(), key=lambda x: x.prob, reverse=True)
				best_confidence = combs[0].prob
				for c in combs:
					if c.prob < 0.001 * best_confidence:
						break
					output.write('\t')
					output.write(str(c))
					output.write('\n')
				output.write('\n')

			if output_ground_truth:
				output.write('Ground Truth:\n')
				output.write(str(eq.segments_truth))

def truth_for_draculae(input_path, output_path):
	files = [f for f in os.listdir(input_path) if os.path.splitext(f)[1] == '.inkml']
	for i, fullname in enumerate(files):
		print('%s (%d/%d)' % (fullname, i + 1, len(files)))
		filename, extension = os.path.splitext(fullname)
		eq = Equation.from_inkml(os.path.join(input_path, fullname))

		with open(os.path.join(output_path, filename + '.csv'), 'w') as output:
			for seg in sorted(eq.segments_truth, key=lambda x: min(x.strokes)):
				mins, maxs = [100000, 100000], [-100000, -100000]
				for snum in seg.strokes:
					stroke = eq.strokes[snum]
					smins, smaxs = stroke.extents
					mins[0] = min(mins[0], smins[0])
					mins[1] = min(mins[1], smins[1])
					maxs[0] = max(maxs[0], smaxs[0])
					maxs[1] = max(maxs[1], smaxs[1])

				line = [seg.symbol]
				line += [str(c) for c in mins + maxs]
				line += [str(stroke) for stroke in sorted(seg.strokes)]
				output.write(','.join(line) + '\n')

if __name__ == '__main__':
	if len(sys.argv) < 3 or sys.argv[1] not in globals():
		usage_statement = [
			'Usage: python segmentation.py <command>',
			'where command is:',
			'get_segmentations <input_path> <output_path>',
			'test_segmentations <input_path>',
			'get_segmentations_fuzzy <input_path> <output_path>',
			'test_segmentations_fuzzy <input_path>',
			'test_classifications <input_path>',
			'count_nonadjacent_strokes <input_path>',
			'get_distance_stats <input_path>',
			'test_dots <input_path>',
			'truth_for_draculae <input_path> <output_path>'
			]
		sys.exit('\n\t'.join(usage_statement))

	# first argument is the function name - call it, passing in the rest of the arguments
	globals()[sys.argv[1]](*sys.argv[2:])
